# `/implement` enforces worktree-per-ticket in its own first step

## Status

Accepted. Governs how `ai-agents/skills/implement/SKILL.md` prevents ticket work from landing
on the default branch.

## Context

`AGENTS.d/git-worktrees.md` documents the bare-worktree layout's core rule — a new branch
means a new worktree, never `git checkout -b` inside the default-branch worktree — but the rule
was advisory only: nothing stopped `/implement` from running directly in the `main` worktree.

A prior attempt enforced this with a `PreToolUse` hook plus a marker file
(`.active-ticket.json`) written by the implement skill to tell the hook "a ticket is in play."
It was ported three times across Claude Code, Codex CLI, and Pi with diverging capability:
Claude Code's hooks support an ask/confirm decision, Codex and Pi only support hard allow/deny.
No research turned up precedent for a marker/state-file mechanism used this way — every real
example of branch-per-task enforcement in AI coding agents and worktree tooling is either an
orchestration step that just creates the worktree up front (Codex Branch Workspaces,
OpenHands' worktree-per-task convention, Claude Code's/Cursor's opt-in worktree session modes),
or a hook intercepting git commands directly (with well-documented friction: absolute-path
requirements, deprecated schemas, false positives on legitimate branch-then-commit sequences). Git itself has no per-worktree hook — a hook applies repo-wide across every worktree, so a hook
scoped to "block commits when a ticket is active" still needs external state to know a ticket
is active, which is exactly what the marker file was for.

The actual mistake in scope is narrower than "any commit on main": it's `/implement` itself
running while the current worktree/clone sits on the default branch. `dispatch-implement`
already isolates parallel children into their own worktree (`isolation: "worktree"`); its
sequential children and any standalone `/implement` invocation inherit whatever branch the
invoking session is already on, which is the actual gap.

## Decision

Move the check into `/implement`'s own first step, as plain skill-instruction text — no hook,
no marker file, no new state:

1. Detect the default branch (`git symbolic-ref --short refs/remotes/origin/HEAD`), since it
   varies per repo — verified in this repo, resolves to `origin/main`. If it's unset, stop and
   ask rather than run an untested network fallback
   (`git remote set-head`/`git remote show origin` were considered and dropped for this reason).
2. If the current branch is the default branch, branch off automatically before doing anything
   else — `git worktree add` in the bare-worktree layout, `git checkout -b` in a normal clone —
   then continue the rest of `/implement` from there. On Claude Code, moving into the new
   worktree needs `EnterWorktree` with `path`; a plain shell `cd` resets on the next tool call —
   verified live that a `cd` to a sibling worktree directory in the Bash tool silently resets to
   the original directory on the next call, so the switch would not actually hold without it.
   Codex CLI's and Pi's shell
   persistence for this case is unverified and flagged as such in `implement/SKILL.md` rather
   than assumed.
3. Name the branch `<type>/<ticket#>-<slug>` (conventional-commit type, ticket number when one
   exists, slug from the ticket/spec title).

This covers a standalone `/implement` call directly. For `dispatch-implement`, it exposed a gap
in that skill's own assumptions, for both dispatch modes: sequential children were assumed to
always commit straight to the invoking branch (true only as long as `/implement` never moved the
workspace itself), and parallel children's step-6 cherry-picks target *the invoking branch*,
which would be the default branch if the parent session started there. `dispatch-implement`'s
step 5 is updated alongside this ADR: whenever a dispatch run — parallel or sequential — would
start on the default branch, the *parent* branches off once, before dispatching the first child,
using the same detection and naming `/implement` uses. Every sequential child's own `/implement`
call then finds itself already off the default branch and commits straight to it in turn, and
every parallel child's integration cherry-picks land on that same feature branch instead of the
default branch — preserving `dispatch-implement`'s original assumptions for both modes rather
than replacing them with a wider integration path. The alternative (let each child branch off
independently and integrate the results one at a time) was rejected: it would spawn one
throwaway worktree per ticket and still land cherry-picks back onto the default branch, which is
the exact outcome this whole mechanism exists to prevent.

This resolves the prior design's capability split for free: the skill follows this as prompt
text, so it behaves identically across runtimes — "detect and just do it" works the same way on
Claude Code, Codex CLI, and Pi, with no ask/confirm-vs-hard-block distinction to reconcile since
no hook is involved.

This nudges against `docs/adr/implement-stays-minimal-dispatch-in-wrapper-skill.md`, which kept
dispatch logic (ticket parsing, parallel/sequential judgment, per-runtime dispatch mechanics,
model selection) out of `/implement` and in the `dispatch-implement` wrapper instead. The
worktree check isn't dispatch logic — it doesn't parse tickets, judge parallelism, or pick a
dispatch primitive — it's a workspace precondition, the same category as the fast-checks step
`/implement` already runs before committing. It stays in scope for that ADR's boundary.

## Rejected alternatives

### Advisory-only (status quo)

Already in place via `AGENTS.d/git-worktrees.md` and clearly insufficient — that's the problem
being solved.

### `PreToolUse` hook + marker file, per runtime

The prior attempt. Rejected: three ports for one rule, diverging ask/deny behavior across
runtimes, a marker file that's new state with its own lifecycle (write, read, staleness, who
clears it), and no precedent anywhere for this shape solving this problem.

### Hard-blocking hook without a marker file

Would need to distinguish "this commit is ticket work" from any other commit on the default
branch (e.g. a docs fix, a version bump) without state to say a ticket is in play — the same
problem the marker file existed to solve, or a hook broad enough to block *every* commit on the
default branch regardless of intent, which is a different and unwanted rule (the grilling
session that produced this ADR confirmed the mistake in scope is `/implement` on the default
branch specifically, not commits on the default branch in general).

### Confirm before creating the worktree, instead of auto-creating

Considered and rejected in favor of auto-create-then-proceed, matching Codex Branch Workspaces
and OpenHands' pattern: the first step of ticket work just creates the workspace, no
interruption. Creating a worktree/branch is cheap and reversible (`git worktree remove`,
`git branch -D`), so it doesn't need a confirm gate the way a destructive action would.
