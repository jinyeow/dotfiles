# Review comments: the format for posted findings

How a review finding reads when it is posted to a pull request. `pr-review` uses it for every
thread it posts, and any other skill that posts review findings uses it too. The readers are the
PR's author and its other reviewers. They see the comment and nothing else: no report, no store,
no lens names.

Severity, blocking and disposition come from [`review-rubric.md`](review-rubric.md). The report
keeps the internal record; a comment carries only what the author needs to act.

## Shape

One thread per finding. Anchor it on the PR's changed lines. Use a file-level thread when the
finding has a file but no line, and a general PR comment when it has no file.

Start with a [Conventional Comments](https://conventionalcomments.org/) label and decoration, in
bold, followed by the one-line problem. Use only these three:

| Disposition | First line |
|---|---|
| `blocking` | `**issue (blocking):** <one-line problem>` |
| `deferred` | `**issue (non-blocking):** <one-line problem>` |
| `note` | `**suggestion (non-blocking):** <one-line problem>` |

`(blocking)` means the PR should not merge until the thread is resolved. `(non-blocking)` means
it can merge without a fix.

For an issue, the next line is the risk line, in plain words, with the final likelihood and
impact:

```
<Severity> risk: <what happens> (<impact> impact), and it needs <trigger> (<likelihood> likelihood).
```

Then, for a blocking issue: why it matters (the failure scenario), the evidence (a short code
excerpt, or what was reproduced), and a suggested fix that stays inside the PR's own changes.

A deferred issue is short: the first line, the risk line, then either "Tracked for a later
change in <full work item URL>." or "No follow-up item."

A note is short: the first line, the corrected text or a suggested wording, then "Low risk.
Update it if you agree, or resolve this thread yourself; it does not need a fix to merge."

## Never in a comment

- Internal identifiers: finding IDs, fingerprints, claim numbers, lens names, store fields,
  validator verdicts, confidence labels.
- Who or what reviewed it: reviewers, validators, subagents, models, tools, the skill, or any
  reference to AI.
- Links to local files, the report, a temp folder or any path outside the repository. Cite repo
  files as `path:line` on the PR's head.
- Bare `#123` or `!123` mentions. Use full URLs only. On Azure DevOps, a thread's URL is
  `<PR URL>?discussionId=<thread id>`; on GitHub, use the `html_url` the API returns.
- An artifact or hyperlink relation between the PR and a work item. On Azure DevOps, completing
  the PR can then complete the work item. Cross-reference by full URL in the text instead.
- Secret values, tokens or personal data. Describe what was found instead.
- Out-of-scope findings: a `pre-existing` finding is never posted, even as a general comment.

Write plain, direct English. Run the text through the `write` skill's rules before posting.

## Example

```markdown
**issue (blocking):** the cleanup step deletes every resource group in the subscription

High risk: the nightly run removes unrelated resource groups (high impact), and it needs only the
next scheduled run (high likelihood).

`scripts/cleanup.ps1:41` filters on `$_.Tags.owner`, but that tag is unset on most groups, so the
filter matches all of them:

    Get-AzResourceGroup | Where-Object { -not $_.Tags.owner -or $_.Tags.owner -eq $Owner }

Suggested fix: drop the `-not $_.Tags.owner` clause, so only groups tagged with `$Owner` match.
```

```markdown
**issue (non-blocking):** the retry loop has no upper bound on its total wait

Low risk: a long outage holds the job for hours (medium impact), and it needs the service to stay
down past the job timeout (low likelihood).

No follow-up item.
```
