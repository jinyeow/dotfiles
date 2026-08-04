---
name: jj
description: "Use when working in a Jujutsu (jj) repository: making/describing changes, syncing with a remote, rewriting history, managing bookmarks or workspaces, or recovering via the op log. Windows/pwsh-native, conventional-commits aware. Does not fire in pure-git repos."
metadata:
  author: justin
  version: "1.0.0"
---

# Jujutsu (jj) workflow

Drive a Jujutsu repository correctly and non-interactively. jj is a git-compatible VCS
where you edit **changes** (mutable, stable change-IDs) rather than commits, there is **no
staging area**, and almost **nothing is lost locally** (the op log records every operation,
so most mistakes are one `jj undo` away). That recoverability is why this is a *workflow*
skill, not a guardrails hook: git needs `reset --hard` blockers because mistakes are
destructive; in jj a bad rebase/squash/describe is reversible. (Caveat: already-pushed
commits are *not* un-pushed by `jj undo`, and old operations can eventually be GC'd.)

This repo's PowerShell prompt already renders jj (`Set-Prompt.ps1` → `Get-JjPromptInfo`),
so the user works in jj day to day. Match its terminology: **change-id**, **bookmark**,
`--ignore-working-copy`.

> Written against **jj 0.42**. The CLI still moves fast — if a flag below is rejected,
> check `jj <cmd> --help` rather than guessing.

## Mental model

- **Change vs commit.** A *change* has a stable change-id that survives rewrites (amend,
  rebase, reword). The underlying git commit hash changes; the change-id does not. Refer to
  work by change-id, not hash.
- **`@` and `@-`.** `@` is the working-copy change (what you're editing now); `@-` is its
  parent. Your edits are continuously snapshotted into `@` — there is no `git add`.
- **No staging area.** You don't stage. To exclude a file from the current change, move it
  to another change with `jj restore` (below) rather than unstaging.
- **Bookmarks are branch-like pointers.** jj changes are anonymous by default. A *bookmark*
  (e.g. `main`) is a named pointer to a change — the closest analogue to a git branch. It
  does **not** auto-advance as you create new changes; you move it explicitly.
- **Colocated repos.** A repo with both `.jj` and `.git` is colocated — git tooling still
  works, but prefer jj commands. The prompt detects this and renders jj instead of git
  (avoids git's detached-HEAD noise).

## Non-interactive discipline (critical for agent use)

Avoid any command that drops you into `$EDITOR` and hangs:

- **`jj describe` and `jj commit` open an editor without `-m`** — always pass `-m "<msg>"`.
- **`jj squash` opens an editor only when it must combine two non-empty descriptions.** Pass
  `-m "<msg>"` to set the squashed description inline (or `-u` /
  `--use-destination-message` to reuse the destination's), which suppresses the editor.
- **`jj new` does *not* open an editor.** It creates a new (undescribed) change; `-m` is
  optional and just sets that change's description inline.
- **`jj split` is interactive by default** (when no filesets are given it opens a diff
  editor). To move a file between changes non-interactively, prefer `jj restore`:
  - `jj restore --from @ --into @- <path>` — push a file's content from `@` down into its
    parent.
  - `jj restore <path>` — discard a file's working-copy changes back to the parent (with
    neither `--from`/`--into`, restore targets the working copy from its parent).
- **`jj diffedit` and `jj resolve` (no `--tool`) are interactive** — avoid; resolve
  conflicts by editing files directly, then the conflict markers clear on the next snapshot.

## Essential commands (PowerShell)

```powershell
jj st                       # working-copy status (@ summary + changed files)
jj log                      # graph of recent changes; add -r '<revset>' to scope
jj diff                     # diff of @ against its parent
jj show <change-id>         # description + diff of a specific change

jj new                      # create a new empty change on top of @ (no editor)
jj new -m "feat: start X"   # ...and set its description inline
jj describe -r @ -m "..."   # set/replace the description of @ (see protocol below)
jj edit <change-id>         # move @ onto an existing change to keep editing it

jj git fetch                # fetch from the remote
jj rebase -o main           # rebase @ (and descendants) onto the latest main (-o = --onto)
jj git push --bookmark feature/x   # push + start tracking that bookmark in one step
jj git push                 # push all tracking bookmarks
```

### Bookmarks

```powershell
jj bookmark list                       # show bookmarks and what they point at
jj bookmark set feature/x -r @         # point/move bookmark feature/x at @
jj bookmark move feature/x --to @      # advance an existing bookmark to @
jj git push --bookmark feature/x       # push it (creates + tracks remote on first push)
```

A bookmark does not follow you — after `jj new` you must `jj bookmark set/move` it to the
change you want to publish, then push.

### Workspaces (jj's worktree equivalent)

```powershell
jj workspace add ../repo-feature       # second working copy sharing one repo/op log
jj workspace list
jj workspace forget <name>             # detach a workspace you no longer need
```

Use a workspace when you'd reach for a git worktree (parallel work on the same repo without
re-cloning).

## Conventional commits

Describe changes with conventional-commit subjects via `jj describe -r @ -m`:
`feat:`, `fix:`, `refactor:`, `perf:`, `docs:`, `chore:`, `test:` (match the repo's recent
history). No AI / "Co-Authored-By" lines.

**Gotcha — the ticket-prefix hook is git-only.** This user's global
`prepare-commit-msg` hook (`git/templates/hooks/`) prepends `[PROJ-123]-` derived from the
branch name. **`jj describe` does not run git hooks**, so on a `feature/PROJ-123-foo`-style
line of work the ticket prefix is **not** added automatically. If the change should carry it,
add it by hand: `jj describe -r @ -m "[PROJ-123]- feat: ..."`.

## Description Check Protocol

Before generating or changing any description:

1. **Read first.** `jj show <target>` (or `jj log -r <target>`). Check whether the change
   already has a non-empty description (first line present).
2. **Never overwrite an existing description** without explicit instruction. If the target
   already has one, stop and confirm rather than clobbering it.
3. **Pick `@` vs `@-` safely.** If `@` is empty (`∅` in the prompt — no file changes), the
   work you mean to describe is usually `@-`. Verify with `jj diff -r @` / `jj diff -r @-`
   before choosing the target.
4. **Stop-and-ask on trunk.** If the target is, or its bookmark is, a trunk
   (`main`, `master`, or any `*@origin`), do not rewrite it — confirm with the user first.
5. Only then `jj describe -r <target> -m "<conventional subject>"`.

## Recovery — almost nothing is lost locally

```powershell
jj op log                    # every operation, newest first, with op-ids
jj undo                      # undo the last operation
jj op restore <op-id>        # restore the whole repo state to a prior operation
```

If a rebase, squash, or describe went wrong, `jj undo` reverses it; `jj op restore` jumps to
any earlier point. Reach for these instead of git reflog gymnastics. (`jj undo` does not
un-push commits already sent to a remote.)

## Differences from git (quick reference)

| git | jj |
|---|---|
| `git add` + commit | no staging — edits auto-snapshot into `@`; `jj describe`/`jj commit -m` |
| branch | bookmark (does not auto-advance) |
| `git commit --amend` | `jj describe -r @` / `jj squash` |
| `git rebase` | `jj rebase -o <dest>` (descendants come along; conflicts are recorded, not blocking) |
| `git worktree` | `jj workspace add` |
| `git reflog` + `reset` | `jj op log` + `jj undo` / `jj op restore` |
| `git push -u origin <b>` | `jj git push --bookmark <b>` |

## Notes

- `jj tug` is **not** a built-in — it's a popular user alias (advance the closest bookmark to
  `@`). Use the portable form `jj bookmark move <name> --to @` (or `jj git fetch` +
  `jj rebase -o <trunk>` to sync) unless the user has defined `tug` themselves.
- A push may prompt for **auth** (SSH key passphrase, ssh-agent, or a credential helper) —
  that's normal credential interaction, not OS elevation. Surface any auth error; don't
  silently skip the push.

---

Structure and the Description Check Protocol adapted from HotThoughts/jj-skills `jj-workflow`
(MIT); rewritten Windows/pwsh-native and wired to this repo's conventions.
