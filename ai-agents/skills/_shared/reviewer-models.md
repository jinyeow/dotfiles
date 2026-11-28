# Reviewer and fixer models

Shared by `code-review`, `fix-findings` and `refine-until-ready`. It sets which models the review
and fixer subagents run on, and how a review calls Codex read-only. When a second opinion from
another model runs, and how its approval works, is set in `AGENTS.md` → "Second opinions from
another model".

Scope: the model aliases below are Claude Code's subagent aliases, and the call shape is for its
`mcp__codex__codex` MCP tool. Codex CLI and Pi select models through their own defaults; no
equivalent pin is defined for them yet. A Codex CLI host has no external Codex to call, so it
skips the Codex second opinion.

## Reviewer models

On Claude Code, lens and validation subagents run on `sonnet` or `opus`. A standalone
`code-review` may run them on `fable` for a light pass. Under `refine-until-ready` they never run on
`fable` unless the user asks.

### Escalation to `opus`

Use `opus`, never `sonnet` or `fable`, for these seats:

- The lens that covers a change to RBAC, PIM or other role and permission assignments, to
  production configuration, or to what runs automatically (pipeline triggers, schedules,
  conditions, branch policies, build validation). This is usually Security or Pipelines.
- A validator batch that holds a multi-part claim a lens rated HIGH or MED: a claim with more
  than one separate fact that needs its own check, for example "the trigger fires on merge" and
  "the connection has no approval check". Use the lens's rating here, because the validator has
  not rated the claim yet.
- Every tie-break validator.

Record each seat's model in the report.

## Fixer pin

This is the single home for fixer-subagent model selection. It applies to `fix-findings`'s fixer
children (also when `refine-until-ready` runs it), and to any other seat whose child applies and
commits code rather than only reviewing (for example a council seat asked to implement).

- Default: `sonnet`. `haiku` is fine for a fully specified single-hunk edit. `opus` for a hard
  fix or one that needs more judgement than Sonnet gives. Never `fable`.
- The pin names tiers, not builds. Each alias resolves to whatever build Claude Code currently
  ships under that name, so do not ask for or record a point version.

## Codex call shape

Every Codex call from a review passes the read-only posture explicitly, as defence in depth over
the MCP registration's `-c sandbox_mode=read-only -c approval_policy=never` (`setup.ps1`):

```
mcp__codex__codex
  approval-policy: never
  sandbox: read-only
  prompt: <lens briefs + rubric + diff command>
```

The tool's own parameters are hyphenated (`approval-policy`, `sandbox`). Config keys are
underscored (`model_reasoning_effort`). The `-c sandbox_mode=…` form belongs to the server
registration, not to a call. Without a `config: { model_reasoning_effort: "<effort>" }` override
on the call, the registration's pinned `medium` effort applies.
