# `/implement` stays Matt-Pocock-minimal; subagent dispatch lives in a wrapper skill

## Context

#207 started as "make `/implement` dispatch a subagent by default," per `claude/CLAUDE.md`'s
plan → implement → review loop (implement stage = one Opus/Sonnet subagent, never Fable).
`ai-agents/skills/implement/SKILL.md` today is upstream-minimal (Matt Pocock's original
shape): run `/tdd` at agreed seams, run fast checks, review, commit. It has no dispatch
logic, no ticket parsing, no model/effort selection.

The user's actual daily habit is prompting "dispatch subagent(s) to `/implement`
#ticketXYZ,#ticketABC" by hand, often enough that `ai-agents/AGENTS.md`'s own authoring rule
("Minimize manually-invoked skills") calls this out as the bar for making a repeated manual
step automatic rather than left as a memorized prefix. Folding that logic straight into
`implement/SKILL.md` (the original #207 framing) would satisfy the automation goal but
directly conflicts with keeping `/implement` close to its minimal upstream shape — ticket
parsing, a parallel-vs-sequential conflict judgment, per-ticket model/effort selection, and
three different per-runtime dispatch mechanisms (Claude's `Agent` tool, Codex's
`[agents.<name>]` tables, Pi's task mechanism) do not fit in a 15-line skill without changing
what it is.

## Decision

Keep `implement/SKILL.md` exactly as it is today — it only ever runs standalone or *inside*
a dispatched subagent, and never orchestrates.

Add a new thin wrapper skill (working name `dispatch-implement`) that owns everything
`/implement` itself won't:

- Parses one or more `#ticket` references from its invocation.
- Judges parallel-vs-sequential per pair of tickets, conservatively: if it cannot confirm the
  tickets' file/scope ownership doesn't overlap, treat them as conflicting and run
  sequentially rather than risk a shared-file clash (`ai-agents/AGENTS.md` — "No writes to
  shared files without a merge step," "Lock the contract first").
- Picks model and effort per ticket rather than a fixed pin.
- Resolves to the current runtime's dispatch primitive: Claude Code's `Agent` tool, a new
  `[agents.implementer]` table in `codex/config.toml` (mirroring the existing `fixer` table's
  pattern/model pin), or Pi's own subagent/task mechanism (per #189).
- Calls `/implement` once per ticket, inside each dispatched unit.

This is the same shape as `review-fix-loop` wrapping `quick-review`/`fix-findings` without
either of those skills knowing a loop exists around them.

## Rejected alternatives

### Bake dispatch logic into `implement/SKILL.md` directly

The original #207 framing. Rejected because it stops `/implement` being Matt-Pocock-minimal
and couples a simple TDD-at-seams skill to per-runtime dispatch mechanics and conflict
judgment — logic that has nothing to do with what `/implement` actually does once it's
running.

### Leave the "dispatch subagent(s) to /implement …" prefix as a manually-typed habit

Status quo. Rejected because the user already prompts this often enough to notice the
repetition, which is exactly the bar `ai-agents/AGENTS.md`'s authoring conventions set for
promoting a manual step to automatic.
