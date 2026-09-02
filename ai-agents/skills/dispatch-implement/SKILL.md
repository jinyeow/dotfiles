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

> **Trial gate (#213): sequential-only for now.** Run every ticket sequentially regardless of what
> step 3's overlap judgment finds — treat every pair as unconfirmed until #213 confirms the base
> flow (parsing, model pick, single dispatch, `/implement` completing inside a child) against real
> usage. Step 3 and step 6 (integration) stay written up below for when #213 lifts this gate; do not
> act on them meanwhile.

1. **Parse the invocation.** Collect every `#<number>` reference (comma- or space-separated) and any
   explicit model/effort override phrased in natural language ("using Opus", "using Sonnet on low").
   No flag grammar; this skill does not consume `--reviewers`-style arguments. Guard clauses:
   - **Zero tickets found** — stop and ask for at least one `#ticket`.
   - **Duplicate ticket IDs** in one invocation — dedupe; dispatch each ticket once.
   - **Multiple conflicting model/effort overrides** in one invocation — stop and ask which one
     applies; do not silently pick one.
   - **Invalid/unrecognized effort value** — no special handling: it is recorded but not applied,
     same as any other effort value (see Effort below).
2. **Read each ticket** from the tracker named in `.agents/workflow.md` (a private
   `.agents/workflow.local.md` takes precedence). Keep each ticket's `Likely files` section — that is
   the input to the next step.
3. **Judge overlap, per pair.** Compare the tickets' file/scope ownership pairwise. Dispatch in
   parallel **only** when every pair is confirmed non-overlapping; otherwise run sequentially, one
   ticket at a time. A ticket with a missing or empty `Likely files` section is unconfirmed, so it is
   sequential. `Likely files` is allowed to go stale (`ai-agents/skills/to-tickets/SKILL.md`), so this
   judgment is a best-effort filter, not a guarantee — the cherry-pick-conflict check in step 6 is the
   real safety net. Beyond exact path-string equality, treat a pair as overlapping when: one ticket's
   file/path is a prefix of (inside) another's declared scope; or either ticket's `Likely files` lists
   a file the other also lists. Conservative by design: false-sequential is slower, false-parallel
   risks two subagents writing the same file (`ai-agents/AGENTS.md` — "Lock the contract first", "No
   writes to shared files without a merge step").
4. **Pick a model per ticket** — judged from that ticket's size and difficulty, not fixed. On Claude
   Code the implement stage is pinned to **Opus or Sonnet, never Fable** (`claude/CLAUDE.md`), so a
   trivial ticket goes to Sonnet and a hard one to Opus. An explicit override replaces the judgment
   (see Override below).
5. **Dispatch**, one subagent per ticket, each prompted to run `/implement` on that ticket and
   nothing else. Parallel units go out in a single message so they actually run concurrently;
   sequential units wait for the previous unit's result before the next dispatch. **Any run —
   parallel or sequential — starting on the default branch:** branch off once, here, before
   dispatching the first child — same detection as `/implement`'s own first step
   (`implement/SKILL.md`, `AGENTS.d/git-worktrees.md`), named `<type>/<epic#>-<slug>` when the
   invocation shares a spec/epic, else `<type>/<ticket#>-<slug>` off the first ticket listed, in
   invocation order. For a sequential run this makes each
   child's own `/implement` call find itself already off the default branch and commit straight
   to it in turn, as originally designed. For a parallel run this matters just as much: step 6
   cherry-picks each isolated child's range onto *the invoking branch*, so if the invoking branch
   were still the default branch, every ticket's commits would land there regardless of the
   child's own isolated branch being fine. Skipping this and leaving the invoking branch as the
   default branch would spawn throwaway worktrees per ticket and land every cherry-pick back onto
   the default branch in step 6 — the exact outcome this whole mechanism exists to prevent.
6. **Integrate parallel children** (sequential children skip this — step 5 already put the
   invoking branch off the default branch before the first one was dispatched, so each commits
   straight to the invoking branch in turn, same as before this ADR). An isolated child commits to
   its own branch in its own worktree, so its work is not on the invoking branch until you bring it
   over. Before dispatch, capture each child's pre-dispatch `HEAD` — that commit is the range base
   for that child's cherry-pick. Once every parallel child has returned, for each in ticket order
   cherry-pick `base..tip` (its own branch tip) onto the invoking branch — the full range, since
   `/implement` does not promise exactly one commit — then run the project's fast checks once over
   the integrated result. The full suite is not re-run post-integration: each child already ran it
   in isolation before its own commit, per `/implement`'s own contract; this is an accepted
   tradeoff for a thin wrapper, not an oversight. On a cherry-pick conflict, run
   `git cherry-pick --abort` to leave the invoking branch clean, then stop and hand back the child
   branch and worktree names; do not resolve it silently, since a conflict here means the
   non-overlapping judgment in step 3 was wrong. Once integration succeeds, remove the child
   worktrees and delete the child branches — their commits are now fully represented on the invoking
   branch via the cherry-picks, so there is no reason to keep them.
7. **Report** per ticket: model used, parallel or sequential and why, the child's outcome, and for a
   parallel run the integration result (integrated cleanly, or which branches are left for the user).

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

The `Agent` tool's model aliases are `opus`, `sonnet`, `haiku`, `fable`. Anything else is an error —
say which aliases exist and stop, never substitute a model the user did not ask for.

- **`opus` and `sonnet`** are honored directly; they satisfy the implement-stage pin.
- **`haiku` and `fable`** collide with it (`claude/CLAUDE.md`: Opus or Sonnet, never Fable). Stop and
  ask rather than honoring or refusing either silently.
- **Effort** has no `Agent` tool parameter — dispatch takes `model` only. Record the requested effort
  and say once that it was not applied; do not invent a field. Same gap as
  [`../_shared/reviewer-models.md`](../_shared/reviewer-models.md) § Effort.

---

## Runtime support

Claude Code only for now. On Codex CLI (`[agents.implementer]` + `spawn_agent`, tracked by #211) and
on Pi (`pi-subagents`, tracked by #212), stop and report that dispatch is not wired there yet rather
than improvising a mechanism.
