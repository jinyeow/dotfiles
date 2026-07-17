#Requires -Version 7
# PreToolUse(Edit|Write) hook: guard the legacy / Linux-snapshot files in the dotfiles repo
# that CLAUDE.md says to "touch only when explicitly asked" - the frozen Linux WM snapshot:
#   - config/bspwm|sxhkd/     (legacy WM configs)
# Emits a PreToolUse `ask` decision so the edit pauses for confirmation rather than being denied
# (these are edited legitimately when asked). Scoped to the dotfiles repo via $env:DOTFILES so
# the globally-wired hook never fires on same-named files in other projects. Reads the tool-call
# JSON on stdin; no-ops silently (exit 0, no output) for anything outside that scope.
$ErrorActionPreference = 'Stop'

$payload = [Console]::In.ReadToEnd()
if (-not $payload) { exit 0 }

try { $call = $payload | ConvertFrom-Json } catch { exit 0 }

$filePath = $call.tool_input.file_path
if (-not $filePath) { exit 0 }

# Can only scope safely when the repo root is known; otherwise no-op (avoids global false fires).
$root = $env:DOTFILES
if (-not $root) { exit 0 }

try {
  $full = [System.IO.Path]::GetFullPath($filePath)
  $rootFull = [System.IO.Path]::GetFullPath($root).TrimEnd('\', '/')
} catch { exit 0 }

$sep = [System.IO.Path]::DirectorySeparatorChar
if (-not $full.StartsWith($rootFull + $sep, [System.StringComparison]::OrdinalIgnoreCase)) { exit 0 }

$rel = $full.Substring($rootFull.Length).TrimStart('\', '/') -replace '\\', '/'

$legacy = '^config/(bspwm|sxhkd)/'
if ($rel -notmatch $legacy) { exit 0 }

@{
  hookSpecificOutput = @{
    hookEventName            = 'PreToolUse'
    permissionDecision       = 'ask'
    permissionDecisionReason = "'$rel' is a legacy / Linux-snapshot file (CLAUDE.md: edit only when explicitly asked). Confirm you intend to edit it."
  }
} | ConvertTo-Json -Depth 5 -Compress
exit 0
