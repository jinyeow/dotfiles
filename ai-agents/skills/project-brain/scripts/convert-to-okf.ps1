#Requires -Version 7
<#
.SYNOPSIS
  Converts project-brain markdown files to OKF v0.2 conformance (#196).

.DESCRIPTION
  Shared, reviewed-once mechanical conversion run by every brain-repo migration batch
  (#197-204) instead of each batch hand-formatting the same transform. Per
  docs/adr/adopt-okf-for-project-brain-markdown.md, it does exactly four things:

    1. Rewrites Obsidian-style wikilinks to OKF markdown-link form:
       [[a/b|label]] -> [label](/a/b.md)
       [[a/b]]       -> [b](/a/b.md)
    2. Inserts a `type:` frontmatter field, inferred from the file's role (core.md,
       STATUS.md, adr/, research/, reports/, tickets/, spikes/, learner.md, kanban.md).
       `index.md` and `log.md` are reserved role filenames and get no `type:`.
    3. On `status`-typed files, computes `stale_after:` as `updated:` + 7 days.
    4. On `adr`/`research`-typed files, adds an empty `verified: []` if absent.
    5. Derives `generated.at` from the file's own add commit in its own repo
       (`git log --diff-filter=A --follow --format=%aI`), taking the oldest such event.
       Omitted entirely when git history has none — never stamped with today's date,
       which would record the migration event, not original authorship. `generated.by`
       is NOT derived here: there is no reliable record of which agent/session
       originally authored a pre-existing file, so guessing would fabricate provenance.
       New files created from `templates/` fill both `by` and `at` by hand at scaffold
       time instead (see templates/core.md, templates/STATUS.md).

  `verified:` is never populated with real entries by this script — only ever inserted
  empty. A later session that genuinely re-confirms a research finding or re-reads an
  ADR writes into it by hand.

  Every insertion is additive and keyed on the target field's absence, so running this
  script twice over the same file makes no further change (idempotent) — safe to
  re-run per migration batch without risk of duplicate frontmatter blocks.

  Out of scope (left to each migration batch, #197-204): converting an ADR's existing
  bullet-list header (Status/Date/Scope/Supersedes) into `status:`/`date:`/`scope:`/
  `supersedes:`/`superseded_by:` frontmatter fields. That per-file remap is judgement
  work (mapping the old Proposed|Accepted|Superseded vocabulary), not mechanical.

.PARAMETER Path
  A single markdown file, or a directory to process recursively (all *.md files under it).

.EXAMPLE
  ./convert-to-okf.ps1 -Path 'E:\Personal Projects\brain'
  ./convert-to-okf.ps1 -Path 'E:\Personal Projects\brain\initiatives\dotfiles\core.md'
#>
[CmdletBinding(SupportsShouldProcess)]
param(
    [Parameter(Mandatory)]
    [string] $Path
)

$ErrorActionPreference = 'Stop'

function Convert-Wikilinks {
    param([string] $Text)

    # [[a/b|label]] -> [label](/a/b.md) — must run before the bare-link pattern.
    $Text = [regex]::Replace($Text, '\[\[([^\]\|]+)\|([^\]]+)\]\]', {
        param($m)
        "[$($m.Groups[2].Value)](/$($m.Groups[1].Value).md)"
    })

    # [[a/b]] -> [b](/a/b.md)
    $Text = [regex]::Replace($Text, '\[\[([^\]\|]+)\]\]', {
        param($m)
        $target = $m.Groups[1].Value
        $label = ($target -split '/')[-1]
        "[$label](/$target.md)"
    })

    return $Text
}

function Get-FrontMatter {
    param([string] $Content)

    if ($Content -match '(?s)^---\r?\n(.*?)\r?\n---\r?\n(.*)$') {
        return [PSCustomObject]@{
            HasFrontMatter = $true
            Lines          = @($Matches[1] -split '\r?\n')
            Body           = $Matches[2]
        }
    }
    return [PSCustomObject]@{
        HasFrontMatter = $false
        Lines          = @()
        Body           = $Content
    }
}

function Test-TopLevelKey {
    param([string[]] $Lines, [string] $Key)
    return [bool]($Lines | Where-Object { $_ -match "^$Key\s*:" })
}

function Get-TopLevelValue {
    param([string[]] $Lines, [string] $Key)
    $line = $Lines | Where-Object { $_ -match "^$Key\s*:\s*(.*)$" } | Select-Object -First 1
    if ($null -eq $line) { return $null }
    if ($line -match "^$Key\s*:\s*(.*)$") { return $Matches[1].Trim() }
    return $null
}

function Get-OkfType {
    param([string] $RelativePath)

    $norm = ($RelativePath -replace '\\', '/')
    $base = Split-Path $norm -Leaf

    if ($norm -match '(^|/)templates/') { return $null }
    if ($base -eq 'index.md' -or $base -eq 'log.md') { return $null }
    if ($base -eq 'core.md') { return 'core' }
    if ($base -eq 'STATUS.md') { return 'status' }
    if ($base -eq 'learner.md') { return 'learner' }
    if ($base -eq 'kanban.md') { return 'kanban' }
    if ($norm -match '(^|/)adr/') { return 'adr' }
    if ($norm -match '(^|/)research/') { return 'research' }
    if ($norm -match '(^|/)reports/') { return 'report' }
    if ($norm -match '(^|/)tickets/') { return 'ticket' }
    if ($norm -match '(^|/)spikes/') { return 'spike' }
    return $null
}

function Find-GitRoot {
    param([string] $StartDir)

    $dir = $StartDir
    while ($dir) {
        if (Test-Path -LiteralPath (Join-Path $dir '.git')) { return $dir }
        $parent = Split-Path -Parent $dir
        if (-not $parent -or $parent -eq $dir) { return $null }
        $dir = $parent
    }
    return $null
}

function Get-GitAddedDate {
    param([string] $RepoRoot, [string] $FilePath)

    $relative = [IO.Path]::GetRelativePath($RepoRoot, $FilePath) -replace '\\', '/'
    $dates = @(& git -C $RepoRoot log --diff-filter=A --follow --format=%aI -- $relative 2>$null)
    if (-not $dates -or $dates.Count -eq 0) { return $null }
    # git log lists newest first; the oldest add event is original authorship.
    return $dates[-1]
}

function ConvertTo-OkfFile {
    [CmdletBinding(SupportsShouldProcess)]
    param([string] $FilePath)

    $original = Get-Content -LiteralPath $FilePath -Raw
    if ($null -eq $original) { $original = '' }

    $relativeForType = $FilePath
    $body = Convert-Wikilinks -Text $original
    $fm = Get-FrontMatter -Content $body
    $lines = [System.Collections.Generic.List[string]]::new()
    $lines.AddRange([string[]]$fm.Lines)

    $type = Get-OkfType -RelativePath $relativeForType

    if ($type -and -not (Test-TopLevelKey -Lines $lines -Key 'type')) {
        $lines.Add("type: $type")
    }

    if ($type -eq 'status' -and -not (Test-TopLevelKey -Lines $lines -Key 'stale_after')) {
        $updatedRaw = Get-TopLevelValue -Lines $lines -Key 'updated'
        if ($updatedRaw) {
            $parsedDate = [datetime]::MinValue
            if ([datetime]::TryParse($updatedRaw, [cultureinfo]::InvariantCulture, [System.Globalization.DateTimeStyles]::None, [ref]$parsedDate)) {
                $staleAfter = $parsedDate.AddDays(7).ToString('yyyy-MM-dd')
                $lines.Add("stale_after: $staleAfter")
            }
        }
    }

    if ($type -in @('adr', 'research') -and -not (Test-TopLevelKey -Lines $lines -Key 'verified')) {
        $lines.Add('verified: []')
    }

    if ($type -and -not (Test-TopLevelKey -Lines $lines -Key 'generated')) {
        $repoRoot = Find-GitRoot -StartDir (Split-Path -Parent $FilePath)
        if ($repoRoot) {
            $at = Get-GitAddedDate -RepoRoot $repoRoot -FilePath $FilePath
            if ($at) {
                $lines.Add('generated:')
                $lines.Add("  at: $at")
            }
        }
    }

    $newFrontMatter = ($lines -join "`n")
    $newContent = if ($lines.Count -gt 0) {
        "---`n$newFrontMatter`n---`n$($fm.Body)"
    } else {
        $fm.Body
    }

    $changed = $newContent -ne $original
    if ($changed -and $PSCmdlet.ShouldProcess($FilePath, 'Convert to OKF')) {
        Set-Content -LiteralPath $FilePath -Value $newContent -NoNewline -Encoding utf8
    }

    return [PSCustomObject]@{
        Path    = $FilePath
        Type    = $type
        Changed = $changed
    }
}

if (-not (Test-Path -LiteralPath $Path)) {
    throw "convert-to-okf.ps1: path not found: $Path"
}

$item = Get-Item -LiteralPath $Path
$files = if ($item.PSIsContainer) {
    Get-ChildItem -LiteralPath $Path -Filter '*.md' -File -Recurse
} else {
    @($item)
}

$results = foreach ($f in $files) {
    ConvertTo-OkfFile -FilePath $f.FullName
}

$results
