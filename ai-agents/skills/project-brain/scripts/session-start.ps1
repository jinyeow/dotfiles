#Requires -Version 7
# project-brain SessionStart loader.
# Reads the SessionStart hook JSON on stdin, resolves the session cwd to a brain + initiative, and
# injects that initiative's core.md + STATUS.md via hookSpecificOutput.additionalContext.
#
# Resolution order:
#   1. In-repo self-contained brain: nearest ancestor with .claude/brain/core.md wins.
#   2. Global brains.json: the entry whose 'scope' is the longest ancestor of cwd -> that brain,
#      then that brain's registry.json (dir-glob -> initiative) picks the initiative.
# Fails safe: any error, or no match, exits 0 with no output (never blocks a session).
$ErrorActionPreference = 'Stop'
# Soft cap for STATUS.md. Above this, the emitted context gets one extra fail-safe warning line
# naming the real line count, so sessions move history to the initiative log.md.
$script:StatusLineCap = 60
# core.md/STATUS.md content is echoed back verbatim; without this, non-ASCII characters (e.g. "->")
# get mangled to stray control bytes by the console's default (non-UTF-8) output codepage, which
# breaks the emitted JSON.
[Console]::OutputEncoding = [System.Text.Encoding]::UTF8

function Read-IfPresent([string]$path) {
    if ($path -and (Test-Path -LiteralPath $path -PathType Leaf)) {
        try { return (Get-Content -LiteralPath $path -Raw) } catch { return $null }
    }
    return $null
}

# Line count of a content string, ignoring a single trailing newline so a file's final
# newline is the terminator, not an extra line. Shared by Format-BrainContext's STATUS.md
# over-cap warning and Get-StaleInitiative's oversize detection so the two never disagree.
function Measure-ContentLine([string]$content) {
    return (($content -replace "`r?`n\z", '') -split "`r`n|`n").Count
}

function Format-BrainContext([string]$id, [string]$title, [string]$homePath, [string]$core, [string]$status) {
    $lines = [System.Collections.Generic.List[string]]::new()
    $header = "[project-brain] Active initiative: $id"
    if ($title) { $header += " - $title" }
    $lines.Add($header + ".")
    $lines.Add("Home: $homePath  (read research/, adr/, reports/ on demand per core.md's map; maintain per the project-brain skill's update contract).")
    if ($core) { $lines.Add("`n===== core.md =====`n$core") }
    if ($status) {
        $lines.Add("`n===== STATUS.md =====`n$status")
        $statusLineCount = Measure-ContentLine $status
        if ($statusLineCount -gt $script:StatusLineCap) {
            $lines.Add("[project-brain] STATUS.md is $statusLineCount lines; the contract caps it at about $($script:StatusLineCap). Move history to log.md in this initiative at the next status update.")
        }
    } else { $lines.Add("`n(No STATUS.md yet - this initiative may be newly scaffolded.)") }
    return ($lines -join "`n")
}

function Send-BrainContext([string]$ctx) {
    if ($ctx) {
        @{ hookSpecificOutput = @{ hookEventName = 'SessionStart'; additionalContext = $ctx } } |
            ConvertTo-Json -Depth 6 -Compress
    }
    exit 0
}

# Resolve the session cwd (already normalised: forward slashes, no trailing slash) to a
# registered initiative via the global brains.json + the matched brain's registry.json.
# Returns a typed row (brain path, initiative id, title, initiative dir) or $null when no
# brains.json, no scope match, no registry, or no dir glob matches. Never calls exit: an
# exit here would escape a caller's inner try/catch and could drop the in-repo context.
function Resolve-RegisteredInitiative([string]$cwdNorm) {
    $brainsFile = Join-Path $HOME '.claude/project-brain/brains.json'
    if (-not (Test-Path -LiteralPath $brainsFile -PathType Leaf)) { return $null }
    $brains = (Get-Content -LiteralPath $brainsFile -Raw | ConvertFrom-Json).brains
    $match = $brains |
        Where-Object {
            $s = ($_.scope -replace '\\', '/').TrimEnd('/')
            $cwdNorm -eq $s -or $cwdNorm.StartsWith($s + '/')
        } |
        Sort-Object { ($_.scope -replace '\\', '/').Length } -Descending |
        Select-Object -First 1
    if (-not $match) { return $null }

    $regFile = Join-Path $match.path 'registry.json'
    if (-not (Test-Path -LiteralPath $regFile -PathType Leaf)) { return $null }
    $registry = Get-Content -LiteralPath $regFile -Raw | ConvertFrom-Json
    if (-not $registry.initiatives) { return $null }

    foreach ($entry in $registry.initiatives.PSObject.Properties) {
        foreach ($glob in $entry.Value.dirs) {
            $pattern = ($glob -replace '\\', '/')
            if ($cwdNorm -like $pattern) {
                return [pscustomobject]@{
                    BrainPath     = $match.path
                    InitiativeId  = $entry.Name
                    Title         = $entry.Value.title
                    InitiativeDir = (Join-Path $match.path "initiatives/$($entry.Name)")
                }
            }
        }
    }
    return $null
}

# One row per ACTIVE initiative (initiatives/<id>/STATUS.md, never initiatives/_archive/*).
# Each row carries the id, the parsed stale_after (a [datetime], or $null when the STATUS.md
# has no parseable one), whether it is stale relative to $today (date-only compare), and the
# STATUS.md line count. Returns all active rows, not only stale ones, so a caller can also
# report initiatives over the size cap even when nothing is stale. Cost: one directory
# listing plus one small -Raw read per STATUS.md, no recursion below initiatives/<id>/.
function Get-StaleInitiative([string]$brainPath, [datetime]$today) {
    $rows = [System.Collections.Generic.List[pscustomobject]]::new()
    $initRoot = Join-Path $brainPath 'initiatives'
    if (-not (Test-Path -LiteralPath $initRoot -PathType Container)) { return $rows }

    $dirs = Get-ChildItem -LiteralPath $initRoot -Directory -ErrorAction SilentlyContinue |
        Where-Object { $_.Name -ne '_archive' }
    foreach ($d in $dirs) {
        $statusPath = Join-Path $d.FullName 'STATUS.md'
        $content = Read-IfPresent $statusPath
        if (-not $content) { continue }

        $staleAfter = $null
        $lines = $content -split "`r`n|`n"
        if ($lines.Count -gt 0 -and $lines[0].Trim() -eq '---') {
            for ($i = 1; $i -lt $lines.Count; $i++) {
                if ($lines[$i].Trim() -eq '---') { break }
                if ($lines[$i] -match '^\s*stale_after:\s*(\S+)') {
                    $raw = $matches[1].Trim("'", '"')
                    try {
                        $staleAfter = [datetime]::ParseExact($raw, 'yyyy-MM-dd', [cultureinfo]::InvariantCulture)
                    } catch { $staleAfter = $null }
                    break
                }
            }
        }

        $rows.Add([pscustomobject]@{
            Id         = $d.Name
            StaleAfter = $staleAfter
            IsStale    = ($null -ne $staleAfter -and $staleAfter.Date -lt $today.Date)
            LineCount  = (Measure-ContentLine $content)
        })
    }
    return $rows
}

# The advisory line for path 2, or '' when nothing is stale and nothing is over the cap.
# Stale names: the first 8 by oldest stale_after first, then "+<K> more" when more than 8.
# Oversize names: STATUS.md line count > cap, most lines first. Shapes per the contract:
#   stale only        -> "[project-brain] <N> initiatives past stale_after: <id> (<date>)[, ...][ +<K> more]."
#   stale + oversize   -> as above plus " Over the size cap: <id> (<n> lines)[, ...]."
#   oversize only      -> "[project-brain] STATUS.md over the size cap: <id> (<n> lines)[, ...]."
function Format-StaleNotice([System.Collections.Generic.List[pscustomobject]]$rows, [int]$cap) {
    $stale = @($rows | Where-Object { $_.IsStale } | Sort-Object { $_.StaleAfter })
    $oversized = @($rows | Where-Object { $_.LineCount -gt $cap } | Sort-Object LineCount -Descending)
    if ($stale.Count -eq 0 -and $oversized.Count -eq 0) { return '' }

    $overNames = ''
    if ($oversized.Count -gt 0) {
        $overNames = ($oversized | ForEach-Object { "$($_.Id) ($($_.LineCount) lines)" }) -join ', '
    }

    if ($stale.Count -gt 0) {
        $staleNames = ($stale | Select-Object -First 8 | ForEach-Object { "$($_.Id) ($($_.StaleAfter.ToString('yyyy-MM-dd')))" }) -join ', '
        $line = "[project-brain] $($stale.Count) initiatives past stale_after: $staleNames"
        if ($stale.Count -gt 8) { $line += " +$($stale.Count - 8) more" }
        $line += "."
        if ($oversized.Count -gt 0) { $line += " Over the size cap: $overNames." }
        return $line
    }
    return "[project-brain] STATUS.md over the size cap: $overNames."
}

try {
    $payload = [Console]::In.ReadToEnd()
    if (-not $payload) { exit 0 }
    $call = $payload | ConvertFrom-Json
    $cwd = if ($call.cwd) { $call.cwd } else { $PWD.Path }
    if (-not $cwd) { exit 0 }
    $cwdNorm = ($cwd -replace '\\', '/').TrimEnd('/')

    # 1) In-repo self-contained brain: walk up for .claude/brain/core.md
    $dir = $cwd
    while ($dir) {
        $cb = Join-Path $dir '.claude/brain'
        if (Test-Path -LiteralPath (Join-Path $cb 'core.md') -PathType Leaf) {
            $core = Read-IfPresent (Join-Path $cb 'core.md')
            $status = Read-IfPresent (Join-Path $cb 'STATUS.md')
            $name = [System.IO.Path]::GetFileName($dir)
            $ctx = Format-BrainContext -id "$name (in-repo)" -title '' -homePath $cb -core $core -status $status
            # Advisory only: if a registered initiative also matches this cwd, name it so the
            # session can read it on demand. The in-repo brain still wins and stays loaded.
            # Isolated try/catch: a resolver failure here must never drop the in-repo context
            # (the outer catch would), so it can only add or omit the notice, never throw out.
            try {
                $shadow = Resolve-RegisteredInitiative $cwdNorm
                if ($shadow) {
                    $ctx += "`n[project-brain] A registered initiative also matches this directory and was NOT loaded: $($shadow.InitiativeId) at $($shadow.InitiativeDir). Read its core.md and STATUS.md if the task concerns it."
                }
            } catch { }
            Send-BrainContext $ctx
        }
        $parent = [System.IO.Path]::GetDirectoryName($dir)
        if (-not $parent -or $parent -eq $dir) { break }
        $dir = $parent
    }

    # 2) Global brains.json -> scope match -> registry -> initiative
    $resolved = Resolve-RegisteredInitiative $cwdNorm
    if (-not $resolved) { exit 0 }
    $core = Read-IfPresent (Join-Path $resolved.InitiativeDir 'core.md')
    $status = Read-IfPresent (Join-Path $resolved.InitiativeDir 'STATUS.md')
    $ctx = Format-BrainContext -id $resolved.InitiativeId -title $resolved.Title -homePath $resolved.InitiativeDir -core $core -status $status
    # Advisory only: name initiatives whose STATUS.md is past stale_after or over the size
    # cap. Isolated try/catch so a scan failure can only omit the line, never drop the
    # loaded context (the outer catch would emit nothing at all).
    try {
        $today = Get-Date
        $rows = Get-StaleInitiative -brainPath $resolved.BrainPath -today $today
        $notice = Format-StaleNotice -rows $rows -cap $script:StatusLineCap
        if ($notice) { $ctx += "`n$notice" }
    } catch { }
    Send-BrainContext $ctx
} catch {
    exit 0
}
