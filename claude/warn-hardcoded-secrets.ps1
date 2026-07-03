#Requires -Version 7
# PostToolUse(Edit|Write) hook: scan content Claude just wrote for hardcoded secrets and feed a
# warning back as `additionalContext` so it gets moved to an env var / secrets manager in the same
# flow. Non-blocking by design (the tool already ran), like the PSScriptAnalyzer lint hook - a
# false-positive-tolerant nudge, not an enforcement gate. Global on purpose: a hardcoded secret is
# bad in any repo. Reads the tool-call JSON on stdin; no-ops silently (exit 0, no output) when the
# written text has no secret-shaped match. Only rule names are reported back, never the values.
$ErrorActionPreference = 'Stop'

$payload = [Console]::In.ReadToEnd()
if (-not $payload) { exit 0 }

try { $call = $payload | ConvertFrom-Json } catch { exit 0 }

$ti = $call.tool_input
# Write -> content; Edit -> new_string. Join so one scan covers both tool shapes.
$text = @($ti.content, $ti.new_string) -join "`n"
if (-not $text.Trim()) { exit 0 }

# name -> regex. Each requires an assigned value so a bare mention of the word does not false-fire.
# The value is either a quoted literal OR a bare secret-shaped token: 12+ chars of [A-Za-z0-9+/=_-]
# with at least one digit and not starting with $ / { - so env refs (=$env:X, =${...}) and plain
# words (=true, =localhost) are skipped while raw .env secrets (KEY=sk-abc123...) are caught.
$rules = [ordered]@{
  'assigned credential (key/secret/token/password)' =
  '(?im)(?<![A-Za-z])(?:api[_-]?key|secret|client[_-]?secret|token|password|passwd|access[_-]?key)(?![A-Za-z])["'']?\s*[:=]\s*(?:["''][^"'']{4,}|(?![$\{])(?=[A-Za-z0-9+/=_-]*\d)[A-Za-z0-9+/=_-]{12,})'
  'private key block'  = '-----BEGIN (?:RSA |EC |OPENSSH |PGP )?PRIVATE KEY-----'
  'AWS access key id'  = '\bAKIA[0-9A-Z]{16}\b'
}

$hits = @(foreach ($name in $rules.Keys) { if ($text -match $rules[$name]) { $name } })
if (-not $hits) { exit 0 }

$file = if ($ti.file_path) { Split-Path -Leaf $ti.file_path } else { 'the edited file' }
$context = "Possible hardcoded secret(s) in ${file}: " + ($hits -join ', ') +
  '. Move these to an environment variable or secrets manager and confirm the file is gitignored.'

@{
  hookSpecificOutput = @{
    hookEventName     = 'PostToolUse'
    additionalContext = $context
  }
} | ConvertTo-Json -Depth 5 -Compress
exit 0
