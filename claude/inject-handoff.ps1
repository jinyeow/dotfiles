#Requires -Version 7
# SessionStart hook: surface a pending handoff to a fresh session. The `handoff` skill writes
# `.claude/handoff.md` in the workspace; nothing auto-reads it, so this hook injects its contents
# as additionalContext at session start. Reads the hook JSON on stdin; does nothing (exit 0, no
# output) unless a handoff file exists for a genuinely fresh session.
#
# Fires only for fresh-context sources (`startup`, `clear`). For `resume`/`compact` the prior
# conversation is still in context, so re-injecting the handoff would be redundant noise.
#
# After injecting, the file is archived to `handoff-<timestamp>.consumed.md` so it is delivered
# once and not replayed into every subsequent fresh session in the same workspace.
$ErrorActionPreference = 'Stop'
# handoff.md content is echoed back verbatim; without this, non-ASCII characters (e.g. "->")
# get mangled to stray control bytes by the console's default (non-UTF-8) output codepage, which
# breaks the emitted JSON.
[Console]::OutputEncoding = [System.Text.Encoding]::UTF8

$payload = [Console]::In.ReadToEnd()
if (-not $payload) { exit 0 }

try { $call = $payload | ConvertFrom-Json } catch { exit 0 }

if ($call.source -notin @('startup', 'clear')) { exit 0 }

$cwd = if ($call.cwd) { $call.cwd } else { $PWD.Path }
$handoff = Join-Path $cwd '.claude/handoff.md'
if (-not (Test-Path -LiteralPath $handoff -PathType Leaf)) { exit 0 }

try { $content = Get-Content -LiteralPath $handoff -Raw } catch { exit 0 }
if (-not $content) { exit 0 }

# Consume the handoff by archiving it with a timestamp, so it is injected once and not replayed
# into every future fresh session. Best-effort: if the rename fails the content is still emitted.
try {
  $stamp = Get-Date -Format 'yyyyMMdd-HHmmss'
  Rename-Item -LiteralPath $handoff -NewName "handoff-$stamp.consumed.md"
} catch {
  Write-Verbose "Could not archive handoff: $_"
}

@{
  hookSpecificOutput = @{
    hookEventName   = 'SessionStart'
    additionalContext = "A handoff document from a previous session follows (now archived " +
      "under ``.claude/`` as ``handoff-<timestamp>.consumed.md``). Read it first to continue the work:`n`n$content"
  }
} | ConvertTo-Json -Depth 5 -Compress
exit 0
