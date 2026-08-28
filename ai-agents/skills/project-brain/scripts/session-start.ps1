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

function Format-BrainContext([string]$id, [string]$title, [string]$homePath, [string]$core, [string]$status) {
    $lines = [System.Collections.Generic.List[string]]::new()
    $header = "[project-brain] Active initiative: $id"
    if ($title) { $header += " - $title" }
    $lines.Add($header + ".")
    $lines.Add("Home: $homePath  (read research/, adr/, reports/ on demand per core.md's map; maintain per the project-brain skill's update contract).")
    if ($core) { $lines.Add("`n===== core.md =====`n$core") }
    if ($status) { $lines.Add("`n===== STATUS.md =====`n$status") }
    else { $lines.Add("`n(No STATUS.md yet - this initiative may be newly scaffolded.)") }
    return ($lines -join "`n")
}

function Send-BrainContext([string]$ctx) {
    if ($ctx) {
        @{ hookSpecificOutput = @{ hookEventName = 'SessionStart'; additionalContext = $ctx } } |
            ConvertTo-Json -Depth 6 -Compress
    }
    exit 0
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
            Send-BrainContext (Format-BrainContext -id "$name (in-repo)" -title '' -homePath $cb -core $core -status $status)
        }
        $parent = [System.IO.Path]::GetDirectoryName($dir)
        if (-not $parent -or $parent -eq $dir) { break }
        $dir = $parent
    }

    # 2) Global brains.json -> scope match -> registry -> initiative
    $brainsFile = Join-Path $HOME '.claude/project-brain/brains.json'
    if (-not (Test-Path -LiteralPath $brainsFile -PathType Leaf)) { exit 0 }
    $brains = (Get-Content -LiteralPath $brainsFile -Raw | ConvertFrom-Json).brains
    $match = $brains |
        Where-Object {
            $s = ($_.scope -replace '\\', '/').TrimEnd('/')
            $cwdNorm -eq $s -or $cwdNorm.StartsWith($s + '/')
        } |
        Sort-Object { ($_.scope -replace '\\', '/').Length } -Descending |
        Select-Object -First 1
    if (-not $match) { exit 0 }

    $regFile = Join-Path $match.path 'registry.json'
    if (-not (Test-Path -LiteralPath $regFile -PathType Leaf)) { exit 0 }
    $registry = Get-Content -LiteralPath $regFile -Raw | ConvertFrom-Json
    if (-not $registry.initiatives) { exit 0 }

    foreach ($entry in $registry.initiatives.PSObject.Properties) {
        foreach ($glob in $entry.Value.dirs) {
            $pattern = ($glob -replace '\\', '/')
            if ($cwdNorm -like $pattern) {
                $initDir = Join-Path $match.path "initiatives/$($entry.Name)"
                $core = Read-IfPresent (Join-Path $initDir 'core.md')
                $status = Read-IfPresent (Join-Path $initDir 'STATUS.md')
                Send-BrainContext (Format-BrainContext -id $entry.Name -title $entry.Value.title -homePath $initDir -core $core -status $status)
            }
        }
    }
    exit 0
} catch {
    exit 0
}
