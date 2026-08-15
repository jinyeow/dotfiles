#Requires -Version 7
# SessionStart hook: nudge when the CURRENT project's auto-memory store is overdue for review.
# Auto-memory (`~/.claude/projects/<slug>/memory/`, auto-loaded via MEMORY.md) accretes silently;
# nothing prompts a periodic cull. This hook injects a one-line "review due" reminder as
# additionalContext when the project's memories have gone >= $ReviewIntervalDays since their last
# review (or since the oldest memory when never reviewed), so stale/duplicate memories get pruned
# or migrated to a durable home (AGENTS.md, project brain, ADR) instead of piling up.
#
# Scope is the current project only: the memory dir is resolved from the SessionStart payload's
# `transcript_path` (its parent is `~/.claude/projects/<slug>/`), which is keyed to the repo, so a
# bare-worktree layout still lands on the right store without guessing the cwd->slug mapping.
#
# A review is recorded by writing an ISO-8601 UTC timestamp to `<memory>/.last-reviewed`; this hook
# only reads it. Fires only for fresh sources (startup/clear) — on resume/compact/fork the prior
# conversation is still in context, so a nudge would be redundant noise. Fail-open: any problem
# exits 0 with no output.
$ErrorActionPreference = 'Stop'
$ReviewIntervalDays = 14

$payload = [Console]::In.ReadToEnd()
if (-not $payload) { exit 0 }

try { $call = $payload | ConvertFrom-Json } catch { exit 0 }

if ($call.source -notin @('startup', 'clear')) { exit 0 }
if (-not $call.transcript_path) { exit 0 }

$memDir = Join-Path (Split-Path -Parent $call.transcript_path) 'memory'
if (-not (Test-Path -LiteralPath $memDir -PathType Container)) { exit 0 }

# Real memories only — the MEMORY.md index is not itself a memory, and the marker is not a .md.
$mems = @(Get-ChildItem -LiteralPath $memDir -Filter '*.md' -File -ErrorAction SilentlyContinue |
    Where-Object { $_.Name -ne 'MEMORY.md' })
if ($mems.Count -eq 0) { exit 0 }

$now = Get-Date
$oldest = ($mems | Sort-Object LastWriteTime | Select-Object -First 1).LastWriteTime
$oldestDays = [int]($now - $oldest).TotalDays

# Reference point for "due": last review if stamped, else the oldest memory so a memory written
# today does not nudge until it has aged past the interval.
$refTime = $oldest
$reviewedInfo = 'never'
$marker = Join-Path $memDir '.last-reviewed'
if (Test-Path -LiteralPath $marker -PathType Leaf) {
    try {
        $raw = (Get-Content -LiteralPath $marker -Raw).Trim()
        $last = [datetime]::Parse($raw, [cultureinfo]::InvariantCulture, [Globalization.DateTimeStyles]::RoundtripKind)
        $refTime = $last
        $reviewedInfo = "$([int]($now - $last).TotalDays)d ago"
    } catch {
        # Unreadable marker — treat as never reviewed rather than failing the session start.
    }
}

if (($now - $refTime).TotalDays -lt $ReviewIntervalDays) { exit 0 }

$noun = if ($mems.Count -eq 1) { 'memory' } else { 'memories' }
$message = "Memory review due for this project: $($mems.Count) $noun, oldest ${oldestDays}d, " +
    "last reviewed $reviewedInfo. Say 'review memory' to audit — classify each entry keep / " +
    "delete (stale or now-false) / migrate to a durable home (ai-agents/AGENTS.md, the project brain, " +
    "or an ADR under docs/adr/), then stamp the review by writing an ISO-8601 UTC timestamp to " +
    "``$marker``."

@{
    hookSpecificOutput = @{
        hookEventName     = 'SessionStart'
        additionalContext = $message
    }
} | ConvertTo-Json -Depth 5 -Compress
exit 0
