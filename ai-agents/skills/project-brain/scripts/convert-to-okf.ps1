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
    3. On `status`-typed files, computes `stale_after:` as `updated:` + 7 days —
       recomputed (in place) on every run, so a later `updated:` edit moves it too.
    4. On `adr`/`research`-typed files, adds an empty `verified: []` if absent.
    5. Derives `generated.at` from the file's own add commit in its own repo
       (`git log --diff-filter=A --follow --format=%aI`), taking the oldest such event.
       Omitted entirely when git history has none — never stamped with today's date,
       which would record the migration event, not original authorship. `generated.by`
       is NOT derived here: there is no reliable record of which agent/session
       originally authored a pre-existing file, so guessing would fabricate provenance.
       New files created from `templates/` fill both `by` and `at` by hand at scaffold
       time instead (see templates/core.md, templates/STATUS.md). If the file already
       has a `generated:` mapping (block-style `generated:\n  by: ...` or inline
       `generated: { by: ... }`) that is missing `at:`, `at:` is backfilled into that
       same mapping rather than left incomplete or duplicated.

  `verified:` is never populated with real entries by this script — only ever inserted
  empty. A later session that genuinely re-confirms a research finding or re-reads an
  ADR writes into it by hand.

  Every insertion is additive and keyed on the target field's absence — `stale_after:`
  is always recomputed from the current `updated:` value, and `generated.at` is keyed on
  its own absence rather than the whole `generated:` mapping's absence (see point 5) — so
  running this script twice over the same file with `updated:` unchanged makes no
  further change (idempotent) — safe to re-run per migration batch without risk of
  duplicate frontmatter blocks or fields.

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

function Format-WikilinkTarget {
    param([string] $Target)

    # Split off a #fragment before appending .md, so the anchor doesn't get folded into
    # the filename, then re-append the fragment after. Split at the FIRST '#' so a nested
    # Obsidian heading link ([[file#H1#H2]]) keeps "H1#H2" as one fragment instead of
    # losing everything up to the last '#'. Slugify the fragment (GitHub heading-anchor
    # style: lowercase, non-alphanumeric runs collapsed to a single '-', leading/trailing
    # '-' trimmed) so a multi-word Obsidian heading doesn't leave a raw space in the link
    # destination — an unencoded space breaks CommonMark link-destination parsing. A
    # fragment that slugifies to nothing (only punctuation, or empty) is dropped rather
    # than emitted as a bare, unresolvable "#". Strip an existing .md suffix from the
    # target first, so a target that already ends in .md doesn't get a second one.
    $fragment = ''
    if ($Target -match '^([^#]*)#(.*)$') {
        $Target = $Matches[1]
        $slug = $Matches[2].ToLower() -replace '[^a-z0-9]+', '-'
        $slug = $slug.Trim('-')
        if ($slug) {
            $fragment = "#$slug"
        }
    }
    $Target = $Target -replace '\.md$', ''
    if (-not $Target) {
        # [[#Heading]] — a bare local-heading link with no path segment before the
        # fragment. OKF's link syntax covers cross-file references, not intra-file
        # headings, so there is no filename to fold ".md" into; emit a plain in-page
        # anchor instead of the malformed "/.md#Heading".
        return $fragment
    }
    if ($Target -match '\.[A-Za-z0-9]+$') {
        # The target already names a concrete non-markdown asset file (image, PDF, etc.)
        # — leave its extension as-is instead of appending a wrong ".md" suffix.
        return "/$Target$fragment"
    }
    return "/$Target.md$fragment"
}

function Convert-WikilinksInSegment {
    param([string] $Text)

    # [[a/b|label]] -> [label](/a/b.md) — must run before the bare-link pattern.
    $Text = [regex]::Replace($Text, '\[\[([^\]\|]+)\|([^\]]+)\]\]', {
        param($m)
        "[$($m.Groups[2].Value)]($(Format-WikilinkTarget $m.Groups[1].Value))"
    })

    # [[a/b]] -> [b](/a/b.md)
    $Text = [regex]::Replace($Text, '\[\[([^\]\|]+)\]\]', {
        param($m)
        $rawTarget = $m.Groups[1].Value
        $labelSource = $rawTarget -replace '#.*$', '' -replace '\.md$', ''
        $label = if ($labelSource) {
            ($labelSource -split '/')[-1]
        } elseif ($rawTarget -match '^#(.*)$') {
            # Bare [[#Heading]] with no explicit label — fall back to the heading text.
            $Matches[1]
        } else {
            ''
        }
        "[$label]($(Format-WikilinkTarget $rawTarget))"
    })

    return $Text
}

function Convert-Wikilinks {
    param([string] $Text)

    # Skip fenced code blocks (``` or ~~~ fences, 3+ delimiters) and inline code spans
    # (backtick runs of 1+) — wikilink-looking text quoted in a code sample or in prose
    # about the syntax itself must not be rewritten. Per CommonMark, a fence's closing
    # delimiter run must be at least as long as its opening run, and an inline span's
    # closing run must match the opening run's exact backtick count — otherwise a longer
    # fence wrapping a shorter literal example (e.g. a 4-backtick fence containing a
    # ``` example) closes early, and a double-backtick span is misparsed as an empty pair.
    # Named groups capture each opening run so \k<...> backreferences require a matching
    # closing run of the same character; the trailing `* / ~* absorbs a closing run that is
    # longer than the opening, per the "at least as long" rule.
    $pattern = '(?<btfence>`{3,})[\s\S]*?\k<btfence>`*' +
    '|(?<tifence>~{3,})[\s\S]*?\k<tifence>~*' +
    '|(?<span>`+)[^\r\n]*?\k<span>'

    $sb = [System.Text.StringBuilder]::new()
    $lastIndex = 0
    foreach ($m in [regex]::Matches($Text, $pattern)) {
        $prose = $Text.Substring($lastIndex, $m.Index - $lastIndex)
        [void]$sb.Append((Convert-WikilinksInSegment -Text $prose))
        [void]$sb.Append($m.Value)
        $lastIndex = $m.Index + $m.Length
    }
    [void]$sb.Append((Convert-WikilinksInSegment -Text $Text.Substring($lastIndex)))
    return $sb.ToString()
}

function Get-FrontMatter {
    param([string] $Content)

    if ($Content -match '(?s)^---\r?\n(.*?)\r?\n---(?:\r?\n(.*))?$') {
        return [PSCustomObject]@{
            HasFrontMatter = $true
            Lines          = @($Matches[1] -split '\r?\n')
            Body           = $(if ($Matches[2]) { $Matches[2] } else { '' })
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
    $output = @(& git -C $RepoRoot log --diff-filter=A --follow --format=%aI -- $relative 2>&1)
    $logExitCode = $LASTEXITCODE
    if ($logExitCode -eq 0) {
        if (-not $output -or $output.Count -eq 0) { return $null }
        # git log lists newest first; the oldest add event is original authorship.
        return $output[-1]
    }

    # git log failed. A repo with no commits yet (unborn HEAD) legitimately has no
    # add-commit history for any file — that is not a tooling failure. Anything else
    # (a corrupt/invalid repo, a corrupt HEAD ref, a bad pathspec, ...) is a real failure
    # and must surface, not be silently treated the same as "no history".
    #
    # `rev-parse --verify -q HEAD` failing is not proof of legitimate unborn HEAD on its
    # own — a corrupt HEAD ref fails that same check. A genuinely unborn HEAD is also a
    # *valid symbolic ref* (HEAD points at a real branch name that simply has no commits
    # yet), so require both: `symbolic-ref -q HEAD` succeeds AND `rev-parse --verify -q
    # HEAD` fails. Anything else falls through to the throw below.
    & git -C $RepoRoot rev-parse --is-inside-work-tree 2>&1 | Out-Null
    if ($LASTEXITCODE -eq 0) {
        & git -C $RepoRoot symbolic-ref -q HEAD 2>&1 | Out-Null
        $isValidSymbolicRef = ($LASTEXITCODE -eq 0)
        & git -C $RepoRoot rev-parse --verify -q HEAD 2>&1 | Out-Null
        $verifyFailed = ($LASTEXITCODE -ne 0)
        if ($isValidSymbolicRef -and $verifyFailed) { return $null }
    }

    throw "Get-GitAddedDate: git log failed (exit $logExitCode) in repo '$RepoRoot' for file '$relative': $($output -join "`n")"
}

function ConvertTo-OkfFile {
    [CmdletBinding(SupportsShouldProcess)]
    param([string] $FilePath)

    $original = Get-Content -LiteralPath $FilePath -Raw
    if ($null -eq $original) { $original = '' }

    $repoRoot = Find-GitRoot -StartDir (Split-Path -Parent $FilePath)
    $relativePath = if ($repoRoot) {
        [IO.Path]::GetRelativePath($repoRoot, $FilePath)
    } else {
        $FilePath
    }
    $fm = Get-FrontMatter -Content $original
    $fm.Body = Convert-Wikilinks -Text $fm.Body
    $lines = [System.Collections.Generic.List[string]]::new()
    $lines.AddRange([string[]]$fm.Lines)

    $type = Get-OkfType -RelativePath $relativePath

    if ($type -and -not (Test-TopLevelKey -Lines $lines -Key 'type')) {
        $lines.Add("type: $type")
    }

    if ($type -eq 'status') {
        $updatedRaw = Get-TopLevelValue -Lines $lines -Key 'updated'
        if ($updatedRaw) {
            $parsedDate = [datetime]::MinValue
            if ([datetime]::TryParse($updatedRaw, [cultureinfo]::InvariantCulture, [System.Globalization.DateTimeStyles]::None, [ref]$parsedDate)) {
                $staleAfter = $parsedDate.AddDays(7).ToString('yyyy-MM-dd')
                $staleAfterLine = "stale_after: $staleAfter"
                $existingIndex = -1
                for ($i = 0; $i -lt $lines.Count; $i++) {
                    if ($lines[$i] -match '^stale_after\s*:') { $existingIndex = $i; break }
                }
                if ($existingIndex -ge 0) {
                    $lines[$existingIndex] = $staleAfterLine
                } else {
                    $lines.Add($staleAfterLine)
                }
            }
        }
    }

    if ($type -in @('adr', 'research') -and -not (Test-TopLevelKey -Lines $lines -Key 'verified')) {
        $lines.Add('verified: []')
    }

    if ($type -and $repoRoot) {
        $generatedIndex = -1
        for ($i = 0; $i -lt $lines.Count; $i++) {
            if ($lines[$i] -match '^generated\s*:') { $generatedIndex = $i; break }
        }

        if ($generatedIndex -lt 0) {
            $at = Get-GitAddedDate -RepoRoot $repoRoot -FilePath $FilePath
            if ($at) {
                $lines.Add('generated:')
                $lines.Add("  at: $at")
            }
        } elseif ($lines[$generatedIndex] -match '^generated\s*:\s*\{(.*)\}\s*$') {
            # Inline-map style: generated: { by: ... }. Backfill at: into the same map
            # if it is missing, rather than leaving the block incomplete.
            $inner = $Matches[1]
            if ($inner -notmatch '(^|,)\s*at\s*:') {
                $at = Get-GitAddedDate -RepoRoot $repoRoot -FilePath $FilePath
                if ($at) {
                    $trimmedInner = $inner.Trim()
                    $newInner = if ($trimmedInner) { "$trimmedInner, at: $at" } else { "at: $at" }
                    $lines[$generatedIndex] = "generated: { $newInner }"
                }
            }
        } else {
            # Block style: generated: on its own line, children indented below it.
            # Backfill at: into that same block if it is missing.
            $blockEnd = $generatedIndex + 1
            $hasAt = $false
            while ($blockEnd -lt $lines.Count -and $lines[$blockEnd] -match '^\s+\S') {
                if ($lines[$blockEnd] -match '^\s+at\s*:') { $hasAt = $true }
                $blockEnd++
            }
            if (-not $hasAt) {
                $at = Get-GitAddedDate -RepoRoot $repoRoot -FilePath $FilePath
                if ($at) {
                    $lines.Insert($blockEnd, "  at: $at")
                }
            }
        }
    }

    # Rebuild the frontmatter block using the file's own dominant line-ending style, so a
    # CRLF file stays CRLF end to end (the body already keeps its original endings
    # untouched) — otherwise a CRLF file would flip its frontmatter to LF on every run,
    # reporting `changed: $true` forever and ending up with mixed line endings.
    $eol = if ($original -match "`r`n") { "`r`n" } else { "`n" }
    $newFrontMatter = ($lines -join $eol)
    $newContent = if ($lines.Count -gt 0) {
        "---$eol$newFrontMatter$eol---$eol$($fm.Body)"
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
