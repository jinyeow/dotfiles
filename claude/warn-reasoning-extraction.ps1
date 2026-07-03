#Requires -Version 7
# UserPromptSubmit + PreToolUse(Edit|Write) hook: detect reasoning-extraction phrasing
# ("explain your reasoning step by step", "show your chain of thought", ...) that can trip
# Claude Fable 5's `reasoning_extraction` refusal and cause a silent fallback to Opus (see
# claude/AGENTS.md -> "Prompting downstream models", lever 5). Dispatches on hook_event_name:
#   - UserPromptSubmit: advisory only - emits `additionalContext` asking Claude to interpret the
#     phrasing as a request for short rationale + assumptions + evidence, and to mention it to the
#     user. Never denies a user prompt.
#   - PreToolUse(Edit|Write): only for config/prompt-bearing files (CLAUDE.md, AGENTS.md,
#     *SKILL.md, agents/*.md, anything under a codex/ dir) - emits `permissionDecision: ask`
#     since a standing reasoning-extraction phrase persisted into config keeps re-triggering the
#     fallback for every subagent/session that reads it.
# Before matching, quoted substrings are stripped (a phrase quoted in prose to describe or ban it
# must not false-fire) and a negation guard skips matches immediately preceded by a negating word
# (never/don't/do not/avoid/no/not). Reads the tool-call JSON on stdin; fails open (exit 0, no
# output) on any parse error, unmatched event/tool, or no match. Only rule names/reasons are
# reported back, never the matched text.
$ErrorActionPreference = 'Stop'

function Test-ReasoningExtraction {
  param([string]$Text)

  if (-not $Text) { return $false }

  # Strip quoted substrings (single, double, backtick) so text that quotes the phrase to
  # discuss or ban it does not false-fire.
  $scrubbed = $Text -replace '"[^"]*"', '' -replace "'[^']*'", '' -replace '`[^`]*`', ''

  $patterns = @(
    'explain your (reasoning|thinking) step[- ]by[- ]step',
    'show your (chain[- ]of[- ]thought|work step[- ]by[- ]step|full reasoning)',
    'think out loud',
    'walk me through your (internal )?reasoning',
    'reason step[- ]by[- ]step',
    'step[- ]by[- ]step reasoning'
  )
  # Negation guard: skip a match when a negating word sits immediately (within ~10 chars,
  # word-boundary anchored) before it - "never explain your reasoning step by step" is guidance
  # against the pattern, not an instance of it.
  $negation = '\b(?:never|don''t|do\s+not|avoid|no|not)\s*$'

  foreach ($pattern in $patterns) {
    foreach ($m in [regex]::Matches($scrubbed, $pattern, 'IgnoreCase')) {
      $start = [Math]::Max(0, $m.Index - 10)
      $preceding = $scrubbed.Substring($start, $m.Index - $start)
      if ($preceding -notmatch $negation) { return $true }
    }
  }
  return $false
}

$payload = [Console]::In.ReadToEnd()
if (-not $payload) { exit 0 }

try { $call = $payload | ConvertFrom-Json } catch { exit 0 }

if ($call.hook_event_name -eq 'UserPromptSubmit') {
  $prompt = $call.prompt
  if (-not $prompt) { exit 0 }
  if (-not (Test-ReasoningExtraction $prompt)) { exit 0 }

  @{
    hookSpecificOutput = @{
      hookEventName     = 'UserPromptSubmit'
      additionalContext = "This prompt asks for step-by-step reasoning / chain-of-thought / thinking out loud. That phrasing can trip Claude Fable 5's reasoning_extraction refusal and cause a silent fallback to Opus. Interpret it as a request for a short rationale plus assumptions and evidence, and mention this to the user."
    }
  } | ConvertTo-Json -Depth 5 -Compress
  exit 0
}

if ($call.hook_event_name -eq 'PreToolUse' -and $call.tool_name -in @('Edit', 'Write')) {
  $ti = $call.tool_input
  $filePath = $ti.file_path
  if (-not $filePath) { exit 0 }

  $normalized = $filePath -replace '\\', '/'
  $leaf = Split-Path -Leaf $normalized
  $isConfigFile = ($leaf -eq 'CLAUDE.md') -or
    ($leaf -eq 'AGENTS.md') -or
    ($leaf -match '(?i)SKILL\.md$') -or
    ($normalized -match '(?i)/agents/[^/]+\.md$') -or
    ($normalized -match '(?i)/codex/')
  if (-not $isConfigFile) { exit 0 }

  # Write -> content; Edit -> new_string. Join so one scan covers both tool shapes.
  $text = @($ti.content, $ti.new_string) -join "`n"
  if (-not $text.Trim()) { exit 0 }
  if (-not (Test-ReasoningExtraction $text)) { exit 0 }

  @{
    hookSpecificOutput = @{
      hookEventName            = 'PreToolUse'
      permissionDecision       = 'ask'
      permissionDecisionReason = "Reasoning-extraction phrasing (e.g. 'explain your reasoning step by step') is being written into a config/prompt-bearing file. That can trip Claude Fable 5's reasoning_extraction refusal for every subagent/session that reads it. Confirm you intend to write this."
    }
  } | ConvertTo-Json -Depth 5 -Compress
  exit 0
}

exit 0
