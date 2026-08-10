---
name: to-pullrequest
description: "Create a pull request on GitHub (`gh pr create`) or Azure DevOps (`az repos pr create`) with a drafted title/body that has been run through the `write` skill first, so AI-sounding prose never ships in a PR description. Use when the user says 'open a PR', 'create a pull request', 'make a PR for this', 'submit this branch for review', or similar phrasing that asks for a brand-new PR to be opened. NOT for reviewing an existing PR (use `review-ado-pr` for Azure DevOps, `quick-review`/`deep-review` for GitHub), NOT for merging/completing a PR, NOT for editing an already-open PR's description, and NOT for CI/merge-gate checks or review-thread resolution — this skill stops once the PR is created."
metadata:
  author: justin
  version: "1.0.0"
---

# Open a pull request (write-drafted, GitHub or Azure DevOps)

Creates a new pull request on GitHub or Azure DevOps with a title and body that have gone
through the `write` skill before the PR is opened — closing the generation-time gap where
"open a PR" routes straight to a raw CLI call with no prose-quality step. See `CONTEXT.md`'s
"Generation-time gap" entry for why widening `write`'s own trigger alone doesn't fix this.

## When to use

- The user asks to open/create a pull request, on GitHub or Azure DevOps, for the current
  branch's committed work.
- NOT for reviewing an existing PR (`review-ado-pr` for Azure DevOps; `quick-review`/
  `deep-review` for GitHub — both take a PR target).
- NOT for merging, completing, or setting auto-complete on a PR.
- NOT for editing the description of a PR that already exists.
- NOT for CI/merge-gate readiness or resolving review threads — out of scope, see below.

## Scope boundary

This skill stops the moment the PR is created and its URL is reported back. CI/merge-gate
readiness, review-thread resolution, and auto-complete/merge are explicitly out of scope for
this skill — they belong to a separate skill if one is wanted later.

## Preconditions

- `gh` CLI authenticated (GitHub) or `az` CLI with the azure-devops extension, logged in
  (`az login`) (Azure DevOps).
- A bare-worktree repo layout uses the convention in the project's `AGENTS.md` → "Git
  worktrees" section (in this dotfiles repo that section lives in `claude/AGENTS.md`, the
  file projected as the installed global `AGENTS.md`): branch work happens in its own
  worktree, never in `main`. In a normal (non-worktree) clone, the branch guard below still
  applies — it just means "not the default branch."

## Steps

1. **Branch guard.** Determine the current branch (`git branch --show-current` — a bare name,
   e.g. `main`) and the repo's default branch, then **normalize both to a bare branch name
   before comparing** — `git symbolic-ref refs/remotes/origin/HEAD` and `az repos show
   --query defaultBranch` return a ref (`refs/remotes/origin/main` / `refs/heads/main`), and
   `gh repo view --json defaultBranchRef --jq .defaultBranchRef.name` returns a bare name
   directly. Strip any `refs/remotes/origin/` or `refs/heads/` prefix before comparing; a raw
   string compare against the ref form silently never matches and lets the guard pass on
   `main`. If the current branch **is** the default branch, refuse and stop — do not open a PR
   from `main`/`master`/the default branch. Point at `AGENTS.md` → "Git worktrees" for the fix
   (branch into its own worktree) rather than re-explaining the convention here.

2. **Dirty-tree guard.** Run `git status --porcelain`. If it is not clean:
   - Ask whether to stage and commit the outstanding changes, or stop.
   - Never draft a PR body that describes uncommitted changes as if they were already part of
     the branch's history — the body must describe committed commits only.

3. **Gather the diff and commits.** `git log <default-branch>..HEAD` and `git --no-pager diff
   <default-branch>...HEAD` (three-dot, merge-base diff) are the source material for the
   title and body. Do not draft from memory of the conversation alone.

4. **Draft the title.** Conventional Commits format (`feat(scope): summary`, `fix: summary`,
   etc.), consistent with this repo's commit convention (see `claude/AGENTS.md` → "Commits" in
   this repo, or the project's own commit convention elsewhere). If the branch has one commit,
   the title can start from that commit's subject; if several, summarize the net change. A
   commit subject can itself contain quotes, backticks, or `$()` — treat the title with the
   same shell-escaping care as the body (step 9), not as a string safe to interpolate
   unescaped into a `--title "<title>"` argument.

5. **Check for a PR template.**
   - GitHub: look for `.github/PULL_REQUEST_TEMPLATE.md` (or `.github/PULL_REQUEST_TEMPLATE/`
     for multiple templates). If present, fill it in section by section rather than
     overwriting it with a freeform body.
   - Azure DevOps: look for `pull_request_template.md` (or `PULL_REQUEST_TEMPLATE.md`) in the
     repo root, `.azuredevops/`, or `docs/` — ADO checks all three by default — or a path
     configured in project settings if none of those are present. If found, fill it in the
     same way.
   - No template found in either case: draft a freeform body (what changed, why, how to
     verify).

6. **Draft the body, then run it through `write`.** Compose the full title + body from steps
   3–5, then invoke the `write` skill on that draft before it goes anywhere near `gh`/`az`.
   This is the step that closes the generation-time gap — do not skip it because the draft
   "looks fine."

7. **Linking — handled per forge, not generically:**
   - **GitHub**: link via body-text keywords only — `Fixes #N` / `Closes #N`. Default to
     same-repository issues (`#N` resolves against the PR's own repo); a cross-repo link
     (`Fixes owner/repo#N`) is possible but only use it when the user explicitly names another
     repository — don't guess at one. Do not use a numeric flag; `gh pr create` has none for
     issue linking.
   - **Azure DevOps**: resolve the work item id and pass it on the `--work-items <id>` flag of
     `az repos pr create` (confirmed via `az repos pr create --help`: `--work-items : IDs of
     the work items to link to the new pull request. Space separated.`). An `AB#123` mention
     inline in the body is optional/supplementary flavor text only — it is never a substitute
     for the `--work-items` flag, since that flag is what actually creates the link.

8. **Draft vs ready.** Ask the user whether the PR should be open for review now or a draft,
   unless they already said so. If they don't answer or don't care, default to a **draft**
   (`--draft` on both `gh pr create` and `az repos pr create`) — never silently open a
   ready-for-review PR.

9. **Write the body to a temp file, never inline.** Save the write-polished body to a temp
   file and pass it by file, not as an inline multi-line string — inline strings break on
   `gh`/`az` shell-escaping (quotes, backticks, `$()`, newlines).
   - GitHub: `gh pr create --title "<title>" --body-file <tmpfile> [--draft]`.
   - Azure DevOps: `az repos pr create` has no native `@file`-style body flag (verified via
     `--help`: `--description -d : Description for the new pull request. Can include markdown.
     Each value sent to this arg will be a new line.`), so read the temp file's content into
     the argument instead of writing it inline — the shell matters here, since `az` works from
     both (`review-ado-pr` notes the same):
     - bash: `az repos pr create --title "<title>" --description "$(cat <tmpfile>)"
       --work-items <id> [--draft true]`.
     - PowerShell: **do not** use `cat`/`Get-Content <tmpfile>` bare inside the double-quoted
       argument — `Get-Content` returns a line array, and PowerShell string interpolation joins
       array elements with spaces, collapsing the multi-line body onto one line (the exact
       failure this step exists to avoid). Use `-Raw` to read it as a single string instead:
       `az repos pr create --title "<title>" --description (Get-Content <tmpfile> -Raw)
       --work-items <id> --draft true`.

10. **Report.** Relay the created PR's URL (and number) back to the user. Stop here — do not
    chain into CI checks, review-thread handling, or merge/auto-complete.

## Gotchas

| What happened | Rule |
|---|---|
| PR opened from `main` because the guard was skipped | Branch guard is step 1, non-negotiable; refuse and point at the `AGENTS.md` worktree convention |
| Body described uncommitted local changes | Dirty-tree guard: stage+commit explicitly first, or stop — never describe an uncommitted diff |
| Body written inline as a `gh pr create --body "..."` heredoc | Always temp-file + `--body-file`/`-d "$(cat file)"`; inline multi-line strings break on shell-escaping |
| GitHub issue linked with a flag that doesn't exist | GitHub linking is body-text keywords only (`Fixes #N`/`Closes #N`), same-repo |
| ADO work item only mentioned as `AB#123` in the text | That's supplementary only; the real link is the `--work-items` flag |
| PR opened straight to ready-for-review without asking | Draft-vs-ready is an explicit step; default to `--draft` when unspecified |
| Body drafted and sent to `gh`/`az` without going through `write` | Step 6 is the point of this skill; never skip it |

## Related

- `write` — the prose-quality pass this skill routes every drafted title/body through (step 6).
- `review-ado-pr` — reviews an *existing* Azure DevOps PR; this skill only creates new ones.
- `AGENTS.md` → "Git worktrees" — the branch-guard convention referenced in step 1.
