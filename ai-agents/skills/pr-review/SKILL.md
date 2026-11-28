---
name: pr-review
description: "Review someone else's pull request on GitHub or Azure DevOps, end to end: resolve it from a URL or id (or list the PRs waiting on your review), check it out in a review worktree, run code-review in others' PR mode (acceptance criteria, target-branch conventions, merged-tree CI, validated findings, a report file), handle re-reviews, and post Conventional Comments threads only after your explicit go-ahead. Use when the user says 'review PR <url>', 'review this ADO PR', 'review azure devops PR <id>', 'review GitHub PR #<n>', 're-review PR <id>', or 'review my pending PRs'. NOT for the user's own branch or working diff (use code-review)."
metadata:
  author: justin
  version: "1.0.0"
---

# Review a pull request

A local skill by this repo's owner, with no external author or upstream copy. It replaces the
earlier Azure DevOps-only review skill.

Review a pull request that someone else wrote, on GitHub or Azure DevOps, and report what blocks
it. The review itself is `code-review` in others' PR mode. This skill gets the PR onto disk,
gathers its context, runs that review, and posts back only when the user says so.

Posting a thread, creating a work item, adding a comment and casting a vote are outward actions.
Each needs the user's explicit go-ahead in this invocation. An approval from an earlier run, or
for a different PR, does not count.

```
/pr-review [<pr-url> | <id> | pending]
```

## Configuration

Machine-local values come from git config, in the untracked `~/.gitconfig.local` that the global
git config includes. This public repo never holds them. Read each with `git config --get <key>`
(`--get-all` for a list):

| Key | Used for | When unset |
|---|---|---|
| `work.adoOrgUrl` | the Azure DevOps organisation URL for a bare id | ask for a URL |
| `work.adoProject` | the Azure DevOps project for a bare id | ask for a URL |
| `prReview.reportDir` | the folder for review reports | ask for a folder |
| `prReview.cloneRoot` | where local clones live, as `<cloneRoot>/<repo>` | clone into the OS temp directory |
| `prReview.deferralParentId` | the work item that deferred follow-up items go under | ask before creating any |
| `prReview.workItemType` | the type of a deferred follow-up item | ask before creating any |
| `prReview.conventionSource` | team standards that count as convention sources; one path or URL per value | none; target-branch files only |

```bash
git config --file ~/.gitconfig.local work.adoOrgUrl https://dev.azure.com/<org>
git config --file ~/.gitconfig.local work.adoProject '<project>'
git config --file ~/.gitconfig.local prReview.reportDir '<path to the reports folder>'
git config --file ~/.gitconfig.local prReview.cloneRoot '<path to the clones folder>'
git config --file ~/.gitconfig.local prReview.deferralParentId <work item id>
git config --file ~/.gitconfig.local prReview.workItemType '<work item type>'
git config --file ~/.gitconfig.local --add prReview.conventionSource '<path to a team standard>'
```

## Steps

### 1. Resolve the PR

- A GitHub URL (`https://github.com/<owner>/<repo>/pull/<n>`), or `#<n>` inside a GitHub clone:
  `gh pr view <n> --repo <owner>/<repo> --json number,title,body,author,state,isDraft,url,baseRefName,headRefName,headRefOid,closingIssuesReferences`.
  The closing issues are the linked items.
- An Azure DevOps URL (`https://dev.azure.com/<org>/<project>/_git/<repo>/pullrequest/<id>`;
  URL-decode the project), or a bare id with `work.adoOrgUrl` and `work.adoProject`:
  `az repos pr show --id <id> --organization <orgUrl> -o json`. Record `status`, `isDraft`,
  `title`, `description`, `createdBy`, `repository.id`, `repository.name`, `sourceRefName`,
  `targetRefName` and `lastMergeSourceCommit.commitId` (the PR head). The linked work items come
  from `az repos pr work-item list --id <id> --organization <orgUrl>`. Read each item's title,
  description and acceptance criteria, then its updates and comments, and keep every change made
  after the PR's last push.
- `pending`, or no PR given: list the open PRs that wait on the user's review, and let them pick.
  - GitHub: `gh search prs --review-requested=@me --state=open`.
  - Azure DevOps: `az repos pr list --status active --organization <orgUrl> --project <project> -o json`,
    filtered to PRs whose `reviewers` include the signed-in user (`az account show --query user.name -o tsv`).

Go on only when the PR is open (`OPEN` or `active`). A `lastMergeCommit` in the Azure DevOps
payload is a merge preview, not proof that the PR merged. Say so when the PR is a draft.

### 2. Set up the review worktree

Review the PR at its head commit, detached, and never in `main`.

- Find the clone at `<cloneRoot>/<repo>`. With no clone there, clone into a new folder in the OS
  temp directory, never into the workspace.
- In the bare-worktree layout, use the permanent detached `review` worktree beside `main`. Create
  it once with `git worktree add --detach ../review`. It must be clean; if it is dirty, stop and
  tell the user.
- Fetch the target branch and the PR head: `git fetch origin <target>`, then
  `git fetch origin pull/<n>/head` on GitHub or `git fetch origin <sourceRefName>` on Azure DevOps.
  Then `git -C <review worktree> checkout --detach <prHead>`.
- Do not use `az repos pr checkout`. It needs a clean tree, moves the current branch, and fails
  when the PR's source branch already has its own worktree.
- Compute `mergeBase = git merge-base origin/<target> <prHead>`. The review diff is
  `git diff <mergeBase>..<prHead>`.

From a shell, the `prr` PowerShell profile helper lists the active Azure DevOps PRs, moves to the
`review` worktree and opens the PR in Neovim through ado-pr.nvim when that plugin is installed.

### 3. Check for a re-review

It is a re-review when the report folder holds a report for this PR (`PR-<id>-*.md`), or the PR
has review threads from the user. Read every existing thread:

- Azure DevOps: `az devops invoke --area git --resource pullRequestThreads --route-parameters project=<project> repositoryId=<repoId> pullRequestId=<id> --http-method GET --api-version 7.1 --organization <orgUrl>`.
- GitHub: the review threads and their `isResolved` state through
  `gh api graphql -f query='query { repository(owner: "<owner>", name: "<repo>") { pullRequest(number: <n>) { reviewThreads(first: 100) { nodes { isResolved path line comments(first: 20) { nodes { author { login } body createdAt } } } } } } }'`.

For each human thread, record its status, file and line, author, first comment, the replies, and
whether it was opened after the last push. Skip system threads.

Take the quick re-review path when all of these hold: the PR head is the commit the newest report
reviewed; the target branch is at the commit that report merged against; the PR description
matches the report's verbatim copy; and no linked work item changed after that report. Then skip
step 5 and only assess the earlier threads. If any condition fails, or you cannot confirm one, do
a full re-review: run step 5 on the whole change, and give the lenses the incremental diff
`git diff <previous head>..<prHead>` as well.

Assess each earlier review thread as Resolved, Partially resolved, Not resolved or Deferred. The
current code decides, not the reply. When a reply states something false that a later reader
could rely on, draft one short correction for the user to post.

For an earlier thread about a missing or weak test that is now marked fixed, check two things:

1. CI runs the test: its path matches the target branch's CI test step (its glob or config).
2. The test catches a break: in a temp copy, never the review worktree, make 2 to 4 small
   deliberate breaks to the logic the thread was about (flip a condition, remove the branch,
   return early). Run the test after each break. It must fail every time.

If CI does not run it, or a break passes, the thread is Partially resolved; name the path or the
break.

### 4. Run the gates

When the diff touches Bicep or ARM, run the local gates and record each result for step 5:

- `bicep build` and `bicep lint` with a standalone Bicep CLI. The Bicep that `az` bundles can be
  old and report different errors; say so when only that one is installed.
- PSRule for Azure through the `bicep-tdd` skill.

If a gate cannot run, say so. Never imply that a compile or lint ran when it did not. A what-if
reads live state, so it runs only under the live checks below.

### 5. Run code-review in others' PR mode

Run `code-review` in others' PR mode with:

- the merge-base and the PR head, in the review worktree;
- the PR's URL, title, author, branches and description, verbatim;
- the linked work items or issues, with their acceptance criteria and later changes;
- the earlier threads and their assessment from step 3, and the gate results from step 4;
- the convention sources: the files on the target branch and each `prReview.conventionSource`;
- the report folder from `prReview.reportDir`.

Live Azure and Azure DevOps reads are off by default. When the user opts in ("check live",
"allow live reads"), read [`references/ado-live-checks.md`](references/ado-live-checks.md) and
give its policy to every lens and validator.

### 6. Present the findings

Give the user, in chat: the verdict line, the blocking findings, the deferred findings and the
notes, the acceptance-criteria checklist, the status of each earlier thread, Not covered, and the
report path. Then show the drafted comments, written with
[`../_shared/review-comments.md`](../_shared/review-comments.md): one per blocking finding and
note, and one per deferred finding the user wants posted. Never post a pre-existing finding.

Ask whether to post them. Post nothing until the user gives an explicit go-ahead in this
invocation, and post only what they approve.

### 7. Post, on the go-ahead

1. Re-fetch the PR. If it is no longer open, or its head moved past the reviewed commit, post
   nothing and tell the user.
2. Azure DevOps: write the approved comments to a JSON file in the OS temp directory and run
   `scripts/Post-PrThreads.ps1` once with `-DryRun`, then for real. It skips a comment that is
   already posted, so a re-run is safe. A non-zero exit means some comments failed: report each
   failed key from the result file.
3. GitHub: post one review with `event: "COMMENT"` through
   `gh api repos/<owner>/<repo>/pulls/<n>/reviews --method POST --input <file>`, with
   `commit_id` set to the reviewed head and one `{ path, line, side: "RIGHT", body }` per inline
   comment. Put a finding with no line in the review body. Drop any comment whose path, line and
   first line match an existing thread.
4. Deferred follow-up work items, only when the user asks for them:
   - Azure DevOps: run `scripts/New-DeferredWorkItem.ps1` with `-ParentId` from
     `prReview.deferralParentId` and `-WorkItemType` from `prReview.workItemType`. Then post each
     created item's thread as `closed`, with "Tracked for a later change in <work item URL>".
     Then run `scripts/Add-WorkItemComments.ps1` with the PR and thread URLs, using the project
     from the work item's URL. Pass an item to the next step only when its previous step worked.
   - GitHub: open an issue with `gh issue create --body-file <file>`.
   - Never add an artifact or hyperlink relation between the PR and a work item.
5. Stop at the first failure and tell the user what was created, so nothing is left orphaned
   without notice.
6. Append a dated posting log (thread, work item and comment ids) to the report. Do not change
   what the report already says.

Every script takes the organisation, project and ids as parameters, supports `-DryRun` (no token,
no network call), retries a 429 or 5xx response with backoff, and writes a result file after each
item.

### 8. Vote, only on request

Never vote unless the user explicitly asks for a vote in this invocation. Then confirm before
casting it: name the vote and the PR, and state anything that argues against it (an unresolved
blocking finding, an earlier thread still open, a newer push, a reviewer's "do not merge").

- Azure DevOps: `az repos pr set-vote --id <id> --vote <approve|approve-with-suggestions|wait-for-author|reject|reset> --organization <orgUrl>`.
  Use only this command, with no REST fallback. If it fails or the permission system denies it,
  report that and stop.
- GitHub: `gh pr review <n> --approve`, `--request-changes` or `--comment`, with `--body-file`.

## Guardrails

- Read-only by default. Threads, work items, comments and votes each need the user's explicit
  go-ahead in this invocation.
- Never review or check out a PR in `main`; use the detached review worktree.
- Live Azure reads are opt-in, and reads that return secrets are never allowed by default (see
  `references/ado-live-checks.md`).
- Nothing posted names a reviewer, a model, a tool or AI, cites an internal id, or links to a
  local file (see `../_shared/review-comments.md`).

## Related

- `code-review`: the review in step 5, with others' PR mode.
- `bicep-tdd`: the IaC gate in step 4.
- `worktree-janitor`: skips the detached `review` worktree.
