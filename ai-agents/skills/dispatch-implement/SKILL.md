---
name: dispatch-implement
description: Dispatch one subagent per ticket to run `/implement` on it. Parses one or more `#ticket` references, judges per pair whether they can run in parallel or must run sequentially, and picks a model per ticket (or honors an explicit override). Use when asked to "dispatch a subagent to implement #123", "/dispatch-implement #123,#124", or to hand one or more tickets off for implementation. NOT for implementing in the current session — that is `/implement` directly.
disable-model-invocation: true
---

# Dispatch Implement

A **thin wrapper** around [`implement`](../implement/SKILL.md). It owns ticket parsing, the
parallel-vs-sequential judgment, model selection, and the dispatch call. It implements nothing
itself, and `/implement` runs unmodified inside each dispatched unit — TDD at agreed seams, fast
checks, review, commit.

## Quick start

```
/dispatch-implement #123
/dispatch-implement #123,#124 [using <model>]
```

---

## Steps

1. **Parse the invocation.** Collect every `#<number>` reference (comma- or space-separated) and any
   explicit model/effort override phrased in natural language ("using Opus", "using Sonnet on low").
   No flag grammar; this skill does not consume `--reviewers`-style arguments.
2. **Read each ticket** from the tracker named in `.agents/workflow.md` (a private
   `.agents/workflow.local.md` takes precedence). Keep each ticket's `Likely files` section — that is
   the input to the next step.
3. **Judge overlap, per pair.** Compare the tickets' file/scope ownership pairwise. Dispatch in
   parallel **only** when every pair is confirmed non-overlapping; otherwise run sequentially, one
   ticket at a time. A ticket with a missing or empty `Likely files` section is unconfirmed, so it is
   sequential. Conservative by design: false-sequential is slower, false-parallel risks two subagents
   writing the same file (`ai-agents/AGENTS.md` — "Lock the contract first", "No writes to shared
   files without a merge step").
4. **Pick a model per ticket** — judged from that ticket's size and difficulty, not fixed. On Claude
   Code the implement stage is pinned to **Opus or Sonnet, never Fable** (`claude/CLAUDE.md`), so a
   trivial ticket goes to Sonnet and a hard one to Opus. An explicit override replaces the judgment
   (see Override below).
5. **Dispatch**, one subagent per ticket, each prompted to run `/implement` on that ticket and
   nothing else. Parallel units go out in a single message so they actually run concurrently;
   sequential units wait for the previous unit's result before the next dispatch.
6. **Report** per ticket: model used, parallel or sequential and why, the child's outcome, and — for
   parallel runs — where each child committed, so leftover worktrees can be reconciled (see
   `worktree-janitor`).

---

## Claude Code dispatch

Use the `Agent` tool, one call per ticket:

- `subagent_type: general-purpose` — the child must have the `Skill` tool, or `/implement`'s own
  `/tdd`, `/code-review`, `/spec-review`, and `/codex-review` steps silently do not happen. The
  tool-scoped specialist agents (`pwsh-implementer`, `csharp-implementer`, …) do not qualify. Never
  `fork`: each ticket wants a fresh agent, not this session's context.
- `model:` set from step 4 or the override.
- `isolation: "worktree"` on **every parallel** child. `/implement` ends by committing, and children
  sharing one worktree share `.git/index` and `HEAD` — non-overlapping source files do not make
  concurrent `git add`/`git commit` safe. If per-child worktree isolation is unavailable, fall back
  to sequential rather than racing the index. Sequential children need no isolation; they commit to
  the current branch in turn.

### Override

Valid values are the `Agent` tool's model aliases: `opus`, `sonnet`, `haiku`, `fable`. Anything else
is an error — say which aliases exist and stop, never substitute a model the user did not ask for.

- **Fable** collides with the implement-stage pin. Stop and ask rather than honoring or refusing it
  silently.
- **Effort** has no `Agent` tool parameter — dispatch takes `model` only. Record the requested effort
  and say once that it was not applied; do not invent a field. Same gap as
  [`../_shared/reviewer-models.md`](../_shared/reviewer-models.md) § Effort.

---

## Runtime support

Claude Code only for now. On Codex CLI (`[agents.implementer]` + `spawn_agent`, tracked by #211) and
on Pi (`pi-subagents`, tracked by #212), stop and report that dispatch is not wired there yet rather
than improvising a mechanism.
