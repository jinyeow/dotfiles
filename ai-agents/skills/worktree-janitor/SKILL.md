---
name: worktree-janitor
description: "Automate the post-merge worktree cleanup ritual for a bare-worktree repo layout: scan every worktree, check merge/completion status (GitHub or Azure DevOps) or the project-brain STATUS.md for local-only work, then remove and branch-delete what is confirmed safe. Use when the user says 'clean up my worktrees', 'clean up worktrees', 'prune merged worktrees', 'worktree janitor', or asks to remove worktrees for branches that have already merged. NOT for creating a new worktree (see `AGENTS.md` → 'Git worktrees'), NOT for reviewing a PR (`review-ado-pr`, `quick-review`/`deep-review`), and NOT for repos that are a normal single-worktree clone — this skill only applies to the bare-worktree layout."
metadata:
  author: justin
  version: "1.0.0"
---

# Worktree janitor

Automates the post-merge worktree cleanup ritual documented in root `AGENTS.md`'s "Git
worktrees" section, without accidentally deleting work still needed. Only ever removes a
worktree/branch once its merge/completion status (or, for local-only work, its project-brain
`STATUS.md`) confirms it is safe, or the user explicitly approves it.

## When to use

- The user asks to clean up, prune, or tidy worktrees after merging PRs.
- Trigger phrases: "clean up my worktrees", "clean up worktrees", "prune merged worktrees",
  "worktree janitor".
- NOT for creating a new worktree (`AGENTS.md` → "Git worktrees" covers that).
- NOT for reviewing an existing PR (`review-ado-pr`, `quick-review`/`deep-review`).
- NOT for a normal single-worktree clone — only applies to the bare-worktree layout (a sibling
  `.bare/` next to `main`, or confirm via `git worktree list`).

## Preconditions

- The repo uses the bare-worktree layout.
- `gh` CLI authenticated (GitHub remotes) and/or `az` CLI with the azure-devops extension,
  logged in (`az login`) (Azure DevOps remotes) — whichever the worktree's remote needs.

## Steps

1. **Scan all worktrees in one sweep.** `git worktree list --porcelain` from any worktree (the
   registry is shared across the whole layout). Exclude from candidacy:
   - the `bare` entry itself,
   - the **main** worktree (never propose removing the one that stays on the default branch),
   - **detached** worktrees (no `branch` line in the porcelain output — e.g. a permanent
     `review` worktree per `review-ado-pr`) — nothing to merge-check, never a cleanup target,
   - Claude Code's agent-managed worktrees under `.claude/worktrees/` (or wherever the local
     harness stages agent sessions) — these are live session state, not stale feature work.

2. **Per remaining worktree, resolve a merge/completion signal — remote first.**
   - Has a remote? Run `git remote get-url origin` in that worktree and route by host:
     - `github.com` → `gh pr list --state merged --head <branch>` — a result means *a* PR from
       that branch name merged.
     - `dev.azure.com` / `visualstudio.com` → `az repos pr list --status completed
       --source-branch <branch>` — a non-empty result means *a* PR from that source branch
       completed.
   - **Both queries match by branch name only, not by commit** — a reused branch name with an
     old merged/completed PR gives a false "merged" signal for new, unrelated commits pushed to
     that name afterward. Before treating either result as the signal, confirm the matched
     PR's head/source commit SHA equals the branch's current local tip
     (`git rev-parse "<branch>"`). If they differ, the matched PR is stale — treat it as no
     signal and fall through to step 3.
   - Treat a merged/completed PR (with a matching head SHA) as the primary, harder-evidence
     signal — prefer it over the `STATUS.md` fallback below even if both happen to be present.

3. **No remote (local-only work) → fall back to the project-brain `STATUS.md`.** Resolve the
   initiative for that worktree's directory via the `project-brain` skill's resolve-and-read
   procedure, then read its `STATUS.md` for a "done" signal. The signal only counts if:
   - the entry **explicitly names this branch or this worktree's work** as done, merged, or
     closed — a generic "resolved" note elsewhere in the file about a different piece of work
     does not transfer to this branch;
   - or the initiative has already moved to `initiatives/_archive/` (archival is itself a
     done signal for everything under it).
   - the `STATUS.md`'s `updated:` field is **7 days old or less**, per the `project-brain`
     skill's own staleness convention. A stale `STATUS.md` (>7 days) is inconclusive even if it
     otherwise names the branch as done — treat it the same as no signal.

   No brain, no matching initiative, an entry that doesn't name this branch/work, or a stale
   `STATUS.md` all count as "no signal" — fall through to step 4, don't guess.

4. **Neither signal exists → prompt for manual approval.** State the worktree, branch, and what
   was checked (remote host queried / brain lookup attempted) so the user can decide with full
   context. Never remove a worktree on an assumption when both signals are absent.

5. **Once confirmed safe (by signal or explicit approval), clean up fully automated:**
   - Switch to the **main** worktree.
   - `git pull` — bring `main` current before removing anything.
   - `git worktree remove "<dir>"` — drops the registration and the directory (git refuses to
     delete a branch while a worktree still holds it, so this always goes first). If this
     refuses because the worktree is dirty (uncommitted or untracked changes), that refusal
     means real local work would be lost — report the worktree and its dirty state to the user
     and stop there; never escalate to `--force`.
   - Before running `-d`, confirm `git merge-base --is-ancestor "<branch>" main` exits `0`.
     `git branch -d` itself only requires the branch's commits to be reachable from *some*
     configured upstream — it can exit successfully without the branch actually being merged
     into `main`, so its own exit code is not a sufficient safety signal on its own. If the
     ancestor check fails, treat this the same as `-d`'s refusal in step 6, not as "already
     safe."
   - `git branch -d "<branch>"` (non-force). This succeeds for a normal/fast-forward merge and
     is itself fully automated — no confirmation needed once step 2–4 already established
     safety and the ancestor check above passed.

   **Quote every dynamic path or branch name.** `<dir>` and `<branch>` are values you
   substitute in per worktree — always wrap them in double quotes (PowerShell string quoting,
   since this repo's tooling is PowerShell-primary) in every command you run yourself. A
   worktree path can contain spaces (this repo's own path does, e.g.
   `E:\Personal Projects\dotfiles\...`), and an unusual branch name can carry shell
   metacharacters; an unquoted substitution breaks or misparses on either.

6. **`-d` refuses ("not fully merged") → squash-merge case, never force it yourself.**
   GitHub's squash-merge rewrites the branch's commits, so `-d` refuses even though every
   change landed. Verify nothing is lost: `git diff main "<branch>" --stat` — **empty** output
   means every change already landed on `main`, so it is safe to add the branch to the batched
   `-D` list. **Non-empty** output means real, unlanded divergence (`-d`'s refusal is telling
   the truth) — stop, surface the diff to the user, and do not add that branch to the batch.
   Do **not** run `git branch -D` yourself — it is denied by a Claude Code hook, and forcing a
   branch delete is an outward, irreversible action this skill never takes unilaterally.
   Instead, collect every branch confirmed safe (empty diff) across the whole sweep and, at the
   end, print one batched command for the user to run themselves, **quoting each branch name in
   the printed command too** — it is copy-pasted verbatim, so an unquoted name is just as much a
   risk there as in a command you run yourself:
   `git branch -D "branch-a" "branch-b" "branch-c"`.

## Report

At the end of a sweep, report: worktrees removed + branches deleted automatically (with the
signal that justified each), worktrees skipped (bare/main/detached/agent-managed), worktrees
that needed manual approval and the outcome, and the single batched `git branch -D ...` command
for any pending squash-merged branches — or state there were none.

## Gotchas

| What happened | Rule |
|---|---|
| Proposed removing `main` or the bare entry | Step 1 excludes bare, main, detached, and `.claude/worktrees/` entries before anything else runs |
| Ran `git branch -D` directly | Never — always print the batched command for the user; the hook denies it for a reason |
| Deleted a branch on a guess when no PR/STATUS signal existed | Step 4 is mandatory: prompt and wait for explicit approval |
| `-d` failure treated as "unmerged, leave it" without checking | Squash merges always fail `-d`; verify with `git diff main <branch> --stat` — empty ⇒ safe to batch for `-D`, non-empty ⇒ real divergence, stop and surface it to the user |

## Related

- `AGENTS.md` → "Git worktrees" — the manual ritual this skill automates.
- `project-brain` — resolve-and-read procedure used for the local-only `STATUS.md` fallback.
- `review-ado-pr` — documents the permanent detached `review` worktree this skill must skip.
