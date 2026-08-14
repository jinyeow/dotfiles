# Reject `--reviewers` on Codex CLI instead of silently no-opping

## Status

Accepted. Governs `--reviewers` handling in `quick-review`, `deep-review`, and
`review-fix-loop` (`ai-agents/skills/`) when the host runtime is Codex CLI.

## Context

`--reviewers <model>[,<model>][:<effort>]` selects reviewer models on Claude Code by
dispatching subagents with an explicit `model` (and, for Codex, a `config:
{ model_reasoning_effort }` override). On Codex CLI, the review skills run *as* Codex
itself and delegate fan-out to Codex's own `spawn_agent` tool. Since #116 (PR #138),
`--reviewers` was accepted on Codex CLI but did nothing: no code mapped its value onto
anything, so it silently fell back to Codex's global default model/effort
(`ai-agents/skills/_shared/reviewer-models.md`).

`spawn_agent`'s confirmed parameters are `agent_type` and the task only (live-tested
against codex-cli 0.147.0, `ai-agents/skills/deep-review/DISPATCH.md`) — there is no
per-call model field. The only place a model/effort could be set is Codex's global
`agents.default_subagent_model` / `agents.default_subagent_reasoning_effort` config,
which is session-wide: writing to it before dispatch to satisfy one `--reviewers`
invocation would change the model for every other subagent spawned in that same Codex
session afterward, not just the review participants.

`--reviewers` is never actually passed when running these skills from a Codex CLI host
today — this was a real gap, but not a live one.

## Decision

`--reviewers` is not a supported flag on Codex CLI. When passed there, the review skill
rejects it with an actionable error rather than accepting and ignoring it. The skills'
Args tables and `reviewer-models.md`'s scope note are updated to say "unsupported on
Codex CLI", not "no-op on Codex CLI" — the flag's absence of effect is no longer framed
as a documented default, but as an invalid input on that host.

## Rejected alternatives

### Leave as documented no-op

Cheapest, already shipped. Rejected because a no-op that's merely documented is still a
silent footgun the moment anyone does pass `--reviewers` on Codex CLI expecting it to
work — they'd get default-model results with no signal anything was ignored.

### Wire it to `agents.default_subagent_model` / `agents.default_subagent_reasoning_effort`

Rejected because these are Codex's *global* defaults, not per-invocation settings.
Wiring `--reviewers` to them would mutate model selection for every subsequently
spawned subagent in that Codex session, not just the review participants — a
correctness/isolation cost with no available narrower alternative, since `spawn_agent`
has no per-call model parameter to target instead. Revisit if a future Codex CLI version
adds one.
