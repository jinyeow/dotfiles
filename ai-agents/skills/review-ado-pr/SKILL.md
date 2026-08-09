---
name: review-ado-pr
description: "Review an Azure DevOps pull request locally, end-to-end. Use when the user says 'review this ADO PR', 'review PR <dev.azure.com url>', 'review azure devops PR <id>', 'review my pending ADO PRs' (no id needed — it discovers), or asks to look over an ADO pull request. Fetches the PR into the dedicated review worktree, runs IaC gates (Bicep), reads the diff, does a cross-model review, and — only on approval — posts inline threads / a vote back. Read-only by default. NOT for GitHub PRs (use the review skill) or the local working diff (use /code-review)."
metadata:
  author: justin
  version: "1.0.0"
---

# Review an Azure DevOps PR (local, read-only by default)

End-to-end local review of an **Azure DevOps** pull request: get it onto disk cleanly, gate it,
read it, review it across models, and report. Posting anything back to the PR (threads, vote) is an
**outward action — only on the user's explicit go-ahead.** `az` works from pwsh or bash.

## When to use

- The user gives an ADO PR URL or id and wants it reviewed.
- Trigger phrases: "review this ADO PR", "review PR <url>", "review azure devops PR <id>",
  "review my pending ADO PRs" (no id — discover via step 1).
- NOT GitHub (use the `review` skill), NOT the uncommitted working diff (use `/code-review`).

## Preconditions

- `az` CLI with the azure-devops extension (`az extension add --name azure-devops`), logged in (`az login`).
- A bare-worktree repo layout with a permanent detached **`review`** worktree beside `main`
  (`git worktree add --detach ../review`). This is the standing local-review workflow — see the
  `local-pr-review` brain initiative / the `review-worktree-workflow` memory.
  No bare-worktree layout? Skip the dedicated `review` worktree — `az repos pr checkout` directly
  in your clone works the same way, you just accept it moves your current branch instead of
  staying isolated.

## Steps

1. **Resolve the PR.** No id/URL given ("review my pending PRs")? Discover first — run inside the
   repo (org/project/repo auto-detect from the remote):
   `az repos pr list --status active --query "[].{id:pullRequestId, title:title, author:createdBy.displayName}" -o table`
   and let the user pick. (From a shell, the `prr` profile helper is the same discovery: fzf-pick →
   review worktree → nvim.) Then:
   `az repos pr show --id <N> --organization <org> --query "{status:status, sourceRefName:sourceRefName, targetRefName:targetRefName, title:title, mergeStatus:mergeStatus}"`.
   - Confirm `status` is `active`. A `lastMergeCommit` in the full payload is a **merge preview**, not
     proof it merged — trust `status`, not the presence of a merge commit.
   - Note the target branch; the review diff is always three-dot against it.

2. **Get the PR onto disk — in the `review` worktree, never in `main`.**
   `cd` to the `review` worktree, then `az repos pr checkout --id <N>`.
   Two gotchas that decide the path:
   - It needs a **clean tree**. If dirty, stop and tell the user.
   - It **fails if the PR's source branch already has its own worktree** (the user's own feature
     branches do). In that case don't checkout — review the existing worktree, or `git fetch origin`
     and review `origin/<target>...origin/<source>` directly (no checkout needed).

3. **Read the diff.** `git --no-pager diff origin/<target>...<prHead>` (three-dot = only the PR's
   changes vs the merge-base). If diffview.nvim is installed, `:DiffviewOpen origin/<target>...HEAD`;
   otherwise fugitive `:Git difftool` or plain `git diff`. Read the changed files at the PR head, not
   the local (possibly stale) working tree.

4. **Gate infrastructure-as-code (if the diff is Bicep/ARM).** Run the local gates, don't eyeball:
   - `bicep build` + `bicep lint` with a **standalone** bicep — the az-bundled bicep can be years old
     (e.g. v0.45) and misreports; note it and don't treat its errors as CI-representative.
   - PSRule for Azure via the `bicep-tdd` skill (WAF policy-as-code).
   - Optional `az deployment group what-if` for a create/delete/modify preview.
   If you cannot run a real gate, say so — never imply a compile/lint happened when it didn't.

5. **Review across models.**
   - Do a multi-dimension pass (correctness, security, IaC-config, conventions) — reach for the
     `quick-review` skill for anything non-trivial, or `deep-review` when the PR's risk earns the
     full seven-dimension fan-out.
   - Offer a **Codex** second opinion (`codex-review` skill). On ADO the branch may be behind the PR
     head, so write the true PR diff to a file and hand Codex that file plus any context it needs.
   - **Verify every claim against the source file or vendor docs before asserting it.** An API/property
     "looks removed" is not a finding until the versioned schema doc confirms it.

6. **Report.** Findings grouped **HIGH / MEDIUM / LOW**, each one line: `file:line — defect — why it
   matters`, with a concrete failure scenario for HIGH/MEDIUM. Call out what you verified as *not* a
   defect. State plainly if a gate couldn't run.

7. **Respond back to ADO — only on explicit approval.** These are outward actions; never auto-post.
   - Inline comment thread (no `az repos pr comment` verb exists):
     ```
     az devops invoke --area git --resource pullRequestThreads --http-method POST \
       --route-parameters project=<p> repositoryId=<repo> pullRequestId=<N> \
       --in-file thread.json --api-version 7.1
     ```
     `thread.json`:
     ```json
     { "comments": [{ "content": "…", "commentType": 1 }],
       "status": 1,
       "threadContext": { "filePath": "/path/to/file",
         "rightFileStart": { "line": 12, "offset": 1 },
         "rightFileEnd":   { "line": 12, "offset": 1 } } }
     ```
   - Vote: `az repos pr set-vote --id <N> --vote approve|approve-with-suggestions|wait-for-author|reject|reset`.

## Guardrails

- **Read-only by default.** No thread, no vote, no completion without the user saying so.
- **Never `az repos pr checkout` inside `main`** — it moves `main` off `main`, breaking the worktree
  layout. Always the detached `review` worktree.
- Findings are claims — carry file:line evidence; verify against source/docs, not memory.

## Related

- `bicep-tdd` — the IaC gate for step 4.  ·  `quick-review` / `deep-review` / `codex-review` — the review passes in step 5.
- `prr` (PowerShell profile helper) — collapses discovery + steps 2–3 from a shell: fzf PR picker →
  review worktree → `nvim "+AdoPrReview <id>"`.
- The `local-pr-review` brain initiative and `ado-pr.nvim` (a Neovim ADO PR plugin folding steps 2–3
  and 7 into the editor: `:AdoPr` pick, `:AdoPrComment`, `:AdoPrVote`).
