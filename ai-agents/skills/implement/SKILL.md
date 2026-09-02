---
name: implement
description: Implement a piece of work from a spec or set of tickets — TDD at agreed seams, review, then commit.
disable-model-invocation: true
---

Implement the work described by the user in the spec or tickets.

**Before anything else, make sure this isn't landing on the default branch.** Determine the
default branch (`git symbolic-ref --short refs/remotes/origin/HEAD`, stripped of the `origin/`
prefix — don't assume `main`/`master`). If that's unset (e.g. a fresh or `--single-branch`
clone with no `origin/HEAD`), stop and ask which branch is the default rather than guessing or
running an untested network fallback. If the current branch is the default branch, branch off
first, automatically, without asking:

- **Bare-worktree layout** (sibling `.bare/`, or `git worktree list` shows more than one entry —
  see [git-worktrees.md](../../AGENTS.d/git-worktrees.md)): from the current worktree,
  `git worktree add ../<branch-dir> -b <branch>` (flatten any `/` in `<branch>` for
  `<branch-dir>`), then move into that new worktree and continue all further work there.
  **Claude Code:** a plain shell `cd` to a sibling worktree directory does not reliably persist
  across tool calls in the sandboxed Bash tool (verified: it silently resets to the original
  directory) — use `EnterWorktree` with `path` set to the new worktree's directory instead. From
  the main session's own launch directory, its first-entry check accepts any path already
  registered in `git worktree list`, so the bare-worktree layout's sibling directory qualifies
  even though it isn't under `.claude/worktrees/`. From a pinned subagent (working directory
  pinned at launch — subagent isolation or an explicit cwd, e.g. a `dispatch-implement` child)
  that finds itself on the default branch, `EnterWorktree`'s contract requires the target to be
  a worktree already under `.claude/worktrees/` of the same repo, so the bare-worktree sibling
  directory does not qualify there: either stop and hand back rather than guess, or use
  `EnterWorktree name:` instead of `git worktree add` + `path` — it creates the new worktree
  under `.claude/worktrees/` and is accepted from a pinned agent. **Codex CLI / Pi:** unverified
  whether their shell tools persist a `cd` across calls the same way — check before relying on
  it, and use their own worktree/session primitive if one exists rather than assuming a bare
  `cd` holds. If persistence can't be confirmed and no such primitive exists, stop and ask the
  user to switch directories manually rather than proceeding on an unverified `cd`.
- **Normal clone**: `git checkout -b <branch>` — no directory change involved, so no `cd`/session
  caveat applies here.

Name `<branch>` as `<type>/<ticket#>-<slug>` (conventional-commit `<type>`, e.g. `feat`/`fix`;
slug from the ticket/spec title) — drop the `<ticket#>-` segment when there's no ticket.

Use `/tdd` where possible, at pre-agreed seams.

Run the project's fast checks (typecheck / lint / analyzer) regularly and single test files as you go; run the full test suite once at the end.

Once done, review the work: run `/code-review` (correctness and cleanups) and `/spec-review` (conformance to the ticket), with `/codex-review` in parallel for a cross-model second opinion.

Commit your work to the current branch with a conventional-commit message.
