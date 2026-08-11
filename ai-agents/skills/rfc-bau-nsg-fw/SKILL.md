---
name: rfc-bau-nsg-fw
description: "Create a BAU (pre-approved, low-risk) \"Request for Change RFC\" work item in the Azure DevOps \"TSC Change Control\" project for a firewall-only or NSG-only rule change, by cloning the field values of the most recent same-scope RFC assigned to you and overriding only what must be fresh. Use when the user says 'raise the RFC', 'create the BAU RFC', 'rfc for this firewall change', 'rfc for this NSG change', or similar. NOT for non-BAU RFCs, NOT for any other BAU RFC type, NOT for a change touching both firewall and NSG config, and NOT for any Azure DevOps organisation other than the one named below. User-invoked only."
disable-model-invocation: true
metadata:
  author: justin
  version: "1.0.0"
---

# Create a BAU firewall/NSG RFC (clone the latest same-scope match)

Creates a real CAB record in Azure DevOps. Never run past the confirmation gate (step 7)
without explicit go-ahead — the record is outward-facing and only cleanly reversible by
manual Recycle-Bin cleanup.

Every repeated field value comes from an existing RFC at runtime, never from this file.
See `docs/adr/rfc-bau-nsg-fw-clone-latest-instead-of-static-template.md` for why.

> **Shell**: PowerShell 7-native. Organisation is
> `https://dev.azure.com/HollardInsuranceRetail`, project is `TSC Change Control`, work
> item type is `Request for Change RFC`.

## No field values in this file — ever

This repository is public. The RFC's repeated fields include internal SharePoint SOP
document URLs, a distribution-list address, a control-centre contact, and a named
colleague's work email. **Do not write any cloned field's value into this file**, and do
not add a values file, a template file, or an example payload with real values.

The prohibition covers the innocuous statics (change model, risk level, picklist
selections) as well as the confidential ones: reintroducing any of them rebuilds the
static-field-block design this skill exists to replace, and that is the path back to a
leak. Only these literals belong here — the organisation URL, project name, work item
type name, the reference names of the forced-fresh fields, and the title patterns.

There is no machine or tenant gate. Without Hollard Azure DevOps access the skill fails
at the `az` authentication step with an ordinary CLI error; that is the intended gate.

## What this skill covers

Single-scope only: a change touching **either** firewall config **or** NSG config, where
an exact-scope prior RFC assigned to you exists to clone. Anything else is a hard stop:

- Scope resolves to both firewall and NSG → stop, not implemented.
- More than one linked PR → stop, not implemented.
- No exact-scope prior RFC assigned to you → stop. There is **no** fallback to an
  any-scope RFC yet, and **no** static template ever.
- Any other RFC type, or any other organisation → stop.

In each case say plainly which case was hit and what was found, then do nothing further.
Do not improvise field values to work around a stop.

## Steps

### 1. Resolve the parent work item

Context-derived, not asked for by default:

- If the conversation is actively about a specific PBI/work item, that item is the parent.
- If the conversation is working from a PR, read its description/commit message for an
  `AB#<id>` reference, or query the PR's linked work items:
  ```powershell
  az repos pr work-item list --id <prId> -o table `
    --org https://dev.azure.com/HollardInsuranceRetail
  ```
- If neither is available, ask for the parent work item ID before continuing — do not
  guess, and do not create the RFC without the parent relation.

### 2. Detect scope from the linked PR diff

Find the parent's linked PRs (`ArtifactLink` → `PullRequest` relations on the parent, via
`az boards work-item show --id <parentId> --org https://dev.azure.com/HollardInsuranceRetail`,
or the PR already in context). **If more than one PR is linked, stop** — multi-PR handling
is not implemented here.

For the single linked PR, resolve its latest iteration first — a PR updated by later
pushes (e.g. review fixes adding a firewall or NSG file) has more than one iteration, and
`pullrequestiterationchanges` only ever returns the diff for the iteration id you pass:

```powershell
az devops invoke --area git --resource pullrequestiterations `
  --route-parameters project=<proj> repositoryId=<repoId> pullRequestId=<prId> `
  --api-version 7.1 --org https://dev.azure.com/HollardInsuranceRetail
```

Take the highest `id` from the returned iterations list, then list the changed paths for
that iteration — not iteration 1 — so the classification below covers the PR's cumulative
diff:

```powershell
az devops invoke --area git --resource pullrequestiterationchanges `
  --route-parameters project=<proj> repositoryId=<repoId> pullRequestId=<prId> iterationId=<latestIterationId> `
  --api-version 7.1 --org https://dev.azure.com/HollardInsuranceRetail
```

Classify each changed path:

- **Firewall** — firewall rule config: `T1/*Firewall*` paths, `AzureFirewallPolicy`,
  `ApplicationRuleCollections`/`NetworkRuleCollections` blocks.
- **NSG** — NSG config: `T2-Infrastructure`'s
  `dist/<SPOKE>/<REGION>/<ENV>/variable.networkSecurityGroups.json`, or any
  `networkSecurityGroups` / `*nsg*.bicep` path.

Paths from both categories → stop (both-scope is not implemented). Exactly one category →
that is the scope. No linked PR at all → stop and ask for the PR, rather than inferring
scope from a title convention; the clone lookup in step 3 depends on the scope being right.

### 3. Find the RFC to clone

Query for the most recent RFC of the **same** scope assigned to you. That is three
predicates, not one — work item type, `System.AssignedTo = @Me`, and a title match — with
a newest-first order:

```powershell
$wiql = @"
SELECT [System.Id] FROM WorkItems
WHERE [System.WorkItemType] = 'Request for Change RFC'
  AND [System.AssignedTo] = @Me
  AND [System.Title] CONTAINS '<full title prefix for the detected scope>'
ORDER BY [System.CreatedDate] DESC
"@
az boards query --wiql $wiql --org https://dev.azure.com/HollardInsuranceRetail `
  --project "TSC Change Control" -o json
```

The title prefix is the **only** reliable scope discriminator, and it must be the full
prefix:

| Detected scope | Title prefix to match |
|---|---|
| firewall | `BAU Firewall Rules` |
| nsg | `BAU NSG Rules` |

Both full prefixes exclude the both-scope title (`BAU Firewall and NSG Rules`); a
shortened match such as `CONTAINS 'NSG'` does not, and would silently clone a both-scope
RFC. Do not "improve" this query to filter on the impacted-services field instead — in
every sampled RFC that field said `Azure Firewall` even on NSG-only changes, so it does
not discriminate scope.

Do not trust `CONTAINS` to have excluded the both-scope title on its own — if Azure DevOps
resolves it as a word match rather than a substring match, all three words of
`BAU NSG Rules` are present in `BAU Firewall and NSG Rules` and the wrong RFC comes back
with no error. **Re-check each candidate's `System.Title` before cloning it, newest
first**: it must start with the expected full prefix and must not contain
`Firewall and NSG`. If the newest candidate fails either check, discard it and re-check the
next candidate down the ordered result list, continuing until one passes; clone the first
one that does. Hard-stop only once every returned candidate has failed the check.

No result → stop, and report that no same-scope RFC assigned to you was found. Do not
widen the query, do not fall back to any-scope, do not invent a template.

Read the matched RFC's full field set:

```powershell
az boards work-item show --id <matchedId> -o json `
  --org https://dev.azure.com/HollardInsuranceRetail
```

### 4. Split the cloned fields into copy-verbatim and forced-fresh

**Forced fresh on every run** (never taken from the clone) — these are the field values
that go into `$freshFields` in step 8:

| Field | Value |
|---|---|
| `System.Title` | `BAU Firewall Rules - for <desc>` or `BAU NSG Rules - for <desc>` (per detected scope) |
| the description text fields | edited in place — step 5 |
| `Custom.ApprovedDeploymentDate` | window start, step 6 |
| `Custom.ApproveddeploymentEndTime` | window end, step 6 (casing is irregular; use it verbatim) |
| `System.AssignedTo` | the creating user |
| `Custom.Primary` | the creating user |

Two more things are always fresh but are **relations, not fields** — they are added via
`/relations/-` patch entries in step 8, not folded into `$freshFields`:

- the parent relation, from step 1
- the PR `ArtifactLink` relation, from step 2

Resolve the creating user once and use it for both identity fields:

```powershell
az account show --query user.name -o tsv
```

**Copied verbatim from the clone**: every other `Custom.*` field, plus the writable
`System.AreaPath`, `System.IterationPath`, and `System.Tags` if the clone has them. That
includes `Custom.Secondary`, the SOP document URLs, the distribution list, and every other
static CAB field. This is the mechanism that keeps confidential values out of this file —
never substitute a hardcoded fallback for a field the clone did not supply.

**Dropped, not copied** — the clone's system-managed and audit fields, which a create
rejects or overwrites: `System.Id`, `System.Rev`, `System.WorkItemType`,
`System.TeamProject`, `System.CreatedBy`, `System.CreatedDate`, `System.ChangedBy`,
`System.ChangedDate`, `System.Watermark`, `System.CommentCount`, any `System.Board*`, and
`System.State`/`System.Reason` — the new RFC stays in its default initial state.

Because the clone is an exact scope match, its scope-worded fields are already correct for
this change. Do not branch or rewrite them. Where a cloned value looks wrong for the scope
(the impacted-services field saying `Azure Firewall` on an NSG change is the known case),
surface it in step 7's table for eyeballing — copying it forward is the specified
behaviour, not a bug to patch here.

### 5. Edit the description in place

Do not regenerate any description from scratch. From the cloned field set, identify the
text fields whose content carries the **prior** change's specifics — observed so far: the
short-description field, the reason-for-change field, the intro line of the CAB document
folder field, and `System.Description` if the cloned item has one. Rewrite only the
concrete specifics that changed (rule/hostname/IP details, ticket references) for the
current change, keeping the cloned structure, phrasing, and HTML markup intact.

Draft `<desc>` from the PR title/description (strip the `feat(...)`/`fix(...)` prefix and
ticket refs) or the parent PBI's title, and reuse it in the title pattern from step 4.

**Guard**: a field whose body carries the SOP document links must have only its intro line
edited. Replacing that field wholesale drops the links and there is no copy of them in
this file to restore from.

### 6. Compute the deployment window

No prompt — always the next full clock hour from invocation, plus two hours:

```powershell
$now = Get-Date
$start = $now.Date.AddHours($now.Hour + 1)   # next full clock hour
$end = $start.AddHours(2)
```

Format both as UTC ISO 8601 `Z` timestamps for `Custom.ApprovedDeploymentDate` and
`Custom.ApproveddeploymentEndTime` — every sampled RFC stored them as UTC, so convert from
local time rather than sending a local-time string.

### 7. Confirmation gate — required before any write

Show the full resolved field table: title, detected scope, the matched RFC's ID and title
(so the clone source is auditable), the edited description fields with their changes
visible, the deployment window in local **and** UTC, the parent work item ID/title, the
linked PR ID, the resolved `System.AssignedTo`/`Custom.Primary`, and every cloned field
being carried forward. Flag anything noted as questionable in step 4.

Wait for explicit go-ahead. An implied "looks fine" is not go-ahead — get a clear yes.

### 8. Create the RFC in one JSON-patch document

**Do not use `az boards work-item create --fields`.** All required fields must be present
at save time — the RFC template rejects a partial create, so fields cannot be split into a
later PATCH. And some cloned values are SharePoint URLs containing `&`: passed as
`--fields` command-line arguments, the `az.cmd` → `cmd.exe` wrapper on Windows treats the
unescaped `&` as a command separator and the create fails with garbage
`'file' is not recognized...` errors.

Both problems disappear by building **one** JsonPatchDocument holding every field, the
parent relation, and the PR `ArtifactLink`, written to a file so no value ever reaches the
command line:

```powershell
function P($field, $value) { @{ op = "add"; path = "/fields/$field"; value = $value } }

# $cloneFields = the copy-verbatim set from step 4; $freshFields = the forced-fresh field
# values only (the step-4 table) — the parent and PR relations are NOT in $freshFields,
# they are added below as their own /relations/- patch entries.
$patch = @(
  $cloneFields.GetEnumerator() | ForEach-Object { P $_.Key $_.Value }
  $freshFields.GetEnumerator() | ForEach-Object { P $_.Key $_.Value }
  @{ op = "add"; path = "/relations/-"; value = @{
      rel = "System.LinkTypes.Hierarchy-Reverse"
      url = "https://dev.azure.com/HollardInsuranceRetail/_apis/wit/workItems/$parentId"
    }
  }
  # PR artifact id: az repos pr show --id <prId> --query artifactId -o tsv --org https://dev.azure.com/HollardInsuranceRetail
  @{ op = "add"; path = "/relations/-"; value = @{
      rel        = "ArtifactLink"
      url        = $prArtifactId
      attributes = @{ name = "Pull Request" }
    }
  }
) | ConvertTo-Json -Depth 5
```

The patch file carries every cloned field value, including the SOP document URLs and the
distribution list — use a unique filename, not a fixed one, and remove it once the invoke
completes or fails:

```powershell
$patchFile = Join-Path $env:TEMP "rfc_create_patch_$([guid]::NewGuid()).json"
Set-Content -Path $patchFile -Value $patch -Encoding utf8

try {
  az devops invoke --area wit --resource workitems `
    --route-parameters project="TSC Change Control" type="Request for Change RFC" `
    --http-method POST `
    --in-file $patchFile `
    --media-type application/json-patch+json `
    --api-version 7.1 --org https://dev.azure.com/HollardInsuranceRetail
} finally {
  Remove-Item -Path $patchFile -Force
}
```

`--media-type application/json-patch+json` is required — `az devops invoke` defaults to
`application/json`, which the create endpoint rejects with
`Valid content types for this method are: application/json-patch+json`.

The `ArtifactLink` relation needs `attributes.name`. `az boards work-item relation add
--relation-type "Artifact Link"` cannot set it and fails server-side with
`Artifact links must have a valid name specified`, so the raw JSON-patch relation above is
the only form that works.

Leave the new item in its default initial state — do **not** transition it toward Complete
or any other state. That workflow step is always manual.

### 9. Validate the write

Immediately after the create, read the new item back and diff it against the intended
field table from step 7 — including the parent relation and the PR `ArtifactLink`:

```powershell
az boards work-item show --id <newId> -o json `
  --org https://dev.azure.com/HollardInsuranceRetail
```

If any field silently did not take (wrong reference name, a picklist rejecting free text,
a relation missing), report exactly which ones rather than reporting success.

### 10. Report the RFC URL

Only after step 9 passes, report the created RFC's URL as part of the success message:

```
https://dev.azure.com/HollardInsuranceRetail/TSC%20Change%20Control/_workitems/edit/<id>
```

## Gotchas

| What happened | Rule |
|---|---|
| A field value got pasted into this file "just for the non-secret ones" | No cloned field's value belongs here, confidential or not — step "No field values in this file" |
| Query matched a both-scope RFC | Match the full title prefix; `CONTAINS 'NSG'` also matches `BAU Firewall and NSG Rules` |
| Scope query filtered on the impacted-services field | That field said `Azure Firewall` even on NSG-only RFCs; only the title discriminates |
| No same-scope RFC found, so an any-scope one was cloned | Hard stop instead — any-scope fallback is not implemented here |
| A CAB document field was regenerated and lost its SOP links | Edit only that field's intro line; the links exist nowhere else to restore from |
| Create attempted with `--fields` | One JSON-patch document via `--in-file`; `&` in cloned URLs breaks `--fields` on Windows |
| Success reported before reading the item back | Step 9's diff runs before step 10's URL, every time |

## Not implemented

- Both-scope (firewall **and** NSG) changes, multiple linked PRs, and any-scope fallback.
- Non-BAU RFCs, other BAU RFC types, and other Azure DevOps organisations.

Each needs its own field-pattern research against real completed RFCs before it can be
templated. Do not invent field values for these paths.
