#Requires -Version 7
# PostToolUse(Edit|Write) hook: lint PowerShell files with PSScriptAnalyzer right after
# Claude edits them, and feed any violations back as `additionalContext` so they get fixed
# in the same flow. Non-blocking by design (the tool already ran) - this is an inner-loop
# nudge, NOT a replacement for the full `-Recurse` run CI does over the whole source tree.
#
# Reads the tool-call JSON on stdin. No-ops silently (exit 0, no output) when the edited
# file is not PowerShell, no longer exists, or PSScriptAnalyzer is unavailable.
$ErrorActionPreference = 'Stop'

$payload = [Console]::In.ReadToEnd()
if (-not $payload) { exit 0 }

try { $call = $payload | ConvertFrom-Json } catch { exit 0 }

$filePath = $call.tool_input.file_path
if (-not $filePath -or $filePath -notmatch '\.ps(m|d)?1$') { exit 0 }
if (-not (Test-Path -LiteralPath $filePath -PathType Leaf)) { exit 0 }
if (-not (Get-Module -ListAvailable -Name PSScriptAnalyzer)) { exit 0 }

Import-Module PSScriptAnalyzer -ErrorAction Stop

# Use the project's ruleset when present (mirrors CI) by walking up from the edited file
# to the nearest settings file; fall back to PSSA defaults.
#
# Both layouts are checked at each level: repos differ on where the ruleset lives, and
# THIS repo keeps it at the root - which is the file CI passes (`-Settings
# ./PSScriptAnalyzerSettings.psd1`). Looking only under `.vscode/` meant falling back to
# defaults here, reporting rules the repo deliberately excludes, so every finding was a
# false positive.
$analyzerArgs = @{ Path = $filePath }
$dir = Split-Path -Parent (Resolve-Path -LiteralPath $filePath)
while ($dir) {
  $candidate = '.vscode/PSScriptAnalyzerSettings.psd1', 'PSScriptAnalyzerSettings.psd1' |
    ForEach-Object { Join-Path $dir $_ } |
    Where-Object { Test-Path -LiteralPath $_ } |
    Select-Object -First 1
  if ($candidate) { $analyzerArgs['Settings'] = $candidate; break }
  $parent = Split-Path -Parent $dir
  if ($parent -eq $dir) { break }
  $dir = $parent
}

$violations = Invoke-ScriptAnalyzer @analyzerArgs
if (-not $violations) { exit 0 }

$lines = $violations | ForEach-Object {
  "  [$($_.Severity)] $($_.RuleName) (line $($_.Line)): $($_.Message)"
}
$context = "PSScriptAnalyzer flagged $(@($violations).Count) issue(s) in $(Split-Path -Leaf $filePath):`n" +
  ($lines -join "`n") + "`nFix these before finishing."

@{
  hookSpecificOutput = @{
    hookEventName     = 'PostToolUse'
    additionalContext = $context
  }
} | ConvertTo-Json -Depth 5 -Compress
exit 0
