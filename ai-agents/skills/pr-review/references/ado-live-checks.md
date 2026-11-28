# Live checks: opt-in, read-only Azure and Azure DevOps reads

Load this file only when the user opts in to live checks for this review ("check live", "allow
live reads"). Without that, lenses and validators make no live calls: a claim that needs live
state is `UNVERIFIABLE`, with the call that would settle it.

Give this policy to every lens and validator. The opt-in covers this review only.

## Allowed

Read-only calls to Azure, Entra ID and Azure DevOps that help judge the change:

- `Get-Az*` and `Get-Mg*` cmdlets, `az ... show` and `az ... list` (including `az ad`,
  `az role assignment list`, `az repos` and `az devops`), and REST `GET` requests.
- The Azure Pipelines preview call: `POST <project URL>/_apis/pipelines/<pipelineId>/preview?api-version=7.1`
  with body `{"previewRun": true}`. It returns the expanded YAML in `finalYaml` and queues no
  run. If it fails with `InvalidGitVersionSpec`, the commit is no longer on a live branch: read
  the templates at that commit instead, and do not retry.
- A what-if on a compiled template you read first, with `-ValidationLevel ProviderNoRbac`, for
  the PR and for the target branch. Treat its result as a hint: it can report changes that are
  not real and does not evaluate `reference()` calls or nested template links.
- KQL, with limits: Log Analytics only on workspaces the PR's resources send logs to, a range of
  90 days or less, and `summarize` or `count` results only; Resource Graph scoped with
  `-Subscription` or `-ManagementGroup`, projecting only the fields you need.

Azure DevOps reads that are known to work (`<p>` is `https://dev.azure.com/<org>/<project>`):

- Environments: `GET <p>/_apis/distributedtask/environments?api-version=7.1`.
- Checks and approvals on a resource: `GET <p>/_apis/pipelines/checks/configurations?resourceType=<environment|endpoint|queue|repository>&resourceId=<id>&$expand=settings&api-version=7.1-preview.1`.
  Both `resourceType` and `resourceId` are required.
- Branch policies for one repository and branch: `GET <p>/_apis/git/policy/configurations?repositoryId=<repoId>&refName=refs/heads/<branch>&api-version=7.1`.
  `_apis/policy/configurations` ignores those filters and returns the whole project's policies.
- Builds for a branch: `GET <p>/_apis/build/builds?repositoryId=<repoId>&repositoryType=TfsGit&branchName=refs/heads/<branch>&$top=<n>&api-version=7.1`.
  For a PR's validation builds, use `branchName=refs/pull/<id>/merge`.

## Never, unless the user names the exact call

- Reads that return secrets: Key Vault secret values, storage or account keys, connection
  strings, publish profiles, SAS tokens, and `listKeys`-style `POST` endpoints.
- Anything that creates, changes or deletes: `New-`, `Set-`, `Update-`, `Remove-`, `Add-`,
  `Grant-` and `Invoke-` cmdlets (except the KQL queries above), `az ... create|update|delete|set|add|assign|invoke`,
  REST `PUT`, `PATCH` and `DELETE`, and a `POST` that is not a documented pure query.
- Running the PR's code, or the repo's code, against a live service. It can do anything, so it
  counts as a write.

When only such a call would settle a claim, do not make it. Mark the claim `UNVERIFIABLE` and
list the call under `Needs approval`:

```
## Needs approval
- Call: <exact command or request>
- Target: <tenant, subscription, scope, resource or project>
- Effect: <what it would change, create, delete or expose>
- Would settle: <the claim, and the question it answers>
```

`pr-review` shows these to the user and makes none of them itself.

## Limits

- At most 6 live calls per lens, or 8 for a networking, RBAC or policy lens, and at most 3 per
  claim for a validator. Each HTTP request counts, including each pass of a loop; token fetches
  do not. Count before each call. At the limit, mark the claim `UNVERIFIABLE` with "live-check
  limit reached" and list the next call under `Needs approval`.
- For a permission claim that spans several Azure DevOps projects, check each affected project.
- If the Azure sign-in has expired, do not retry and do not sign in. Mark the claims that need
  live Azure evidence `UNVERIFIABLE` with "Azure sign-in expired". Azure DevOps reads still go
  ahead.

## Safety

- Never run `Set-AzContext`, `Select-AzSubscription` or `Connect-AzAccount`. With context autosave
  on, they change the default context of every session. Pass `-Subscription` or
  `-DefaultProfile` instead.
- Write your own read-only queries as separate commands. Never make a live read through the code
  under review.
- When you run tests or snippets of the code under review, mock every Azure, Entra and Azure
  DevOps command they can reach, and read the script first to confirm nothing reaches a live
  service unmocked. Fake ids do not help: the call still goes out with the user's credentials.
  Run it in a child process that starts with
  `Disable-AzContextAutosave -Scope Process | Out-Null; Clear-AzContext -Scope Process -Force -ErrorAction SilentlyContinue`,
  so a missed mock fails locally.
- Never copy a secret value or personal data (names, user principal names, IP addresses tied to a
  person) into a finding, the facts file or the report. Describe the result instead, for example
  "412 sign-ins from 3 addresses in the last 30 days".
- Public web lookups (vendor docs, public issue trackers) do not count as live calls. A query
  holds no organisation, resource or project names, no IP addresses and no ids.
- Record each live call and its result in the facts file, as a fact: the call and what it
  returned, never the conclusion.
- If you make a call outside this policy by mistake, stop using that approach and report the
  exact call, its target and its result.
