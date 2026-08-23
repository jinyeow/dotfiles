---
name: rfc
description: "Draft and create an Azure DevOps \"Request for Change RFC\" work item in the \"TSC Change Control\" project. Args-routed: `/rfc bau firewall/nsg` (also `bau firewall` / `bau nsg`) creates a BAU (pre-approved, low-risk) firewall/NSG-rule-change RFC — single-scope, both-scope, and multi-PR are all handled, by cloning the field values of the most recent matching RFC assigned to you and overriding only what must be fresh. Use when the user says 'raise the RFC', 'create the BAU RFC', 'rfc for this firewall change', 'rfc for this NSG change', or similar. `/rfc <description>` (non-BAU) and `/rfc bau <other-type>` (other BAU RFC types) are not yet implemented. NOT for any Azure DevOps organisation other than the one named below. User-invoked only."
disable-model-invocation: true
metadata:
  author: justin
  version: "2.0.0"
---

# /rfc

Creates a real CAB record in Azure DevOps. Never run past the confirmation gate (step 7)
without explicit go-ahead — the record is outward-facing and only cleanly reversible by
manual Recycle-Bin cleanup.

Every repeated field value comes from an existing RFC at runtime, never from this file.
See `docs/adr/rfc-bau-nsg-fw-clone-latest-instead-of-static-template.md` for why.

> **Shell**: PowerShell 7-native. Organisation is
> `https://dev.azure.com/HollardInsuranceRetail`, project is `TSC Change Control`, work
> item type is `Request for Change RFC`.

## Routing

Parse `$ARGUMENTS` (case-insensitive):

- `bau firewall/nsg`, `bau firewall`, or `bau nsg` → the BAU firewall/NSG path below. All
  three forms name the same RFC *category* — the actual firewall/NSG/both scope is
  auto-detected in step 2, not taken from which phrase was typed.
- Anything else (a bare description, or `bau <other-type>`) → reply that only
  `bau firewall/nsg` is implemented so far, and stop. Do not improvise a template for an
  untested RFC type.

## BAU firewall/NSG path

Steps 1–10 below implement this path in full: single-scope, both-scope, multi-PR, and
any-scope fallback are all handled.

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

Single-scope (firewall-only or NSG-only), both-scope (a change touching both firewall
and NSG config), and any number of linked PRs — see steps 2–3. Cloning falls back from an
exact-scope match to any-scope only when no exact-scope prior RFC exists (step 3), and
that fallback is always flagged, never silent. Everything else is still a hard stop:

- No matching prior RFC assigned to you exists at all, of any scope → stop. There is
  **no** fallback to a static template, ever.
- Any other RFC type, any other BAU RFC type, or any other Azure DevOps organisation →
  stop (see Routing above).

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

### 2. Detect scope from the linked PR diff(s)

Find the parent's linked PRs (`ArtifactLink` → `PullRequest` relations on the parent, via
`az boards work-item show --id <parentId> --org https://dev.azure.com/HollardInsuranceRetail`,
or the PR already in context). **Keep the full list of linked PR IDs** — step 8 attaches
every one of them to the RFC as its own `ArtifactLink` relation, not just the first.

For each linked PR, resolve its own `project`/`repositoryId` first — firewall config
lives in a different repo from NSG config (see the classification below), so a both-scope
multi-PR change routinely means one PR per repo, and reusing the first PR's repo id for a
second PR's diff would silently pull the wrong data:

```powershell
az repos pr show --id <prId> -o json --org https://dev.azure.com/HollardInsuranceRetail |
  ConvertFrom-Json | Select-Object -ExpandProperty repository
```

Then resolve that PR's latest iteration — a PR updated by later pushes (e.g. review
fixes adding a firewall or NSG file) has more than one iteration, and
`pullrequestiterationchanges` only ever returns the diff for the iteration id you pass:

```powershell
az devops invoke --area git --resource pullrequestiterations `
  --route-parameters project=<proj> repositoryId=<repoId> pullRequestId=<prId> `
  --api-version 7.1 --org https://dev.azure.com/HollardInsuranceRetail
```

Take the highest `id` from the returned iterations list, then list the changed paths for
that iteration — not iteration 1 — so the classification below covers each PR's
cumulative diff:

```powershell
az devops invoke --area git --resource pullrequestiterationchanges `
  --route-parameters project=<proj> repositoryId=<repoId> pullRequestId=<prId> iterationId=<latestIterationId> `
  --api-version 7.1 --org https://dev.azure.com/HollardInsuranceRetail
```

Classify each changed path, across **all** linked PRs combined:

- **Firewall** — firewall rule config: `T1/*Firewall*` paths, `AzureFirewallPolicy`,
  `ApplicationRuleCollections`/`NetworkRuleCollections` blocks.
- **NSG** — NSG config: `T2-Infrastructure`'s
  `dist/<SPOKE>/<REGION>/<ENV>/variable.networkSecurityGroups.json`, or any
  `networkSecurityGroups` / `*nsg*.bicep` path.

Paths from both categories anywhere across the linked PRs → scope is `both` — a
firewall-only PR plus an NSG-only PR linked to the same parent is `both`, the same as one
PR touching both. Paths from only one category → that is the scope.

No linked PR found at all → fall back to conversation context and the PR title
convention (`feat(fw)` vs `feat(nsg)`) as a cross-check, rather than asking for a PR.
State clearly in the step-7 confirmation table that scope was **inferred**, not detected
from a diff.

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
| both | `BAU Firewall and NSG Rules` |

Each full prefix excludes the other two titles; a shortened match such as `CONTAINS
'NSG'` does not, and would silently clone the wrong-scope RFC. Do not "improve" this
query to filter on the impacted-services field instead — in every sampled RFC that field
said `Azure Firewall` even on NSG-only changes, so it does not discriminate scope.

Do not trust `CONTAINS` to have excluded the other titles on its own — if Azure DevOps
resolves it as a word match rather than a substring match, all three words of
`BAU NSG Rules` are present in `BAU Firewall and NSG Rules` and the wrong RFC comes back
with no error. **Re-check each candidate's `System.Title` before cloning it, newest
first**: it must start with the expected full prefix, and must not start with either of
the other two full prefixes. If the newest candidate fails either check, discard it and
re-check the next candidate down the ordered result list, continuing until one passes;
clone the first one that does. Move to the any-scope fallback below only once every
returned candidate has failed the check, or the query returned nothing.

**Any-scope fallback** — only once the exact-scope query above is exhausted. Re-run the
same query with the title predicate dropped (work item type + assigned-to-me only),
newest first, and apply the **same** candidate re-check as above — the returned title
must start with one of the three full prefixes; discard and walk down otherwise. Clone
the first candidate that passes, but mark it in the step-7 confirmation table as an
**inferred fallback** clone (its scope prefix does not match the detected scope), never
as a silent exact match.

No result at all — exact-scope and any-scope both exhausted — → stop, and report that no
BAU firewall/NSG RFC assigned to you was found at all. Do not invent a template.

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
| `System.Title` | `BAU Firewall Rules - for <desc>`, `BAU NSG Rules - for <desc>`, or `BAU Firewall and NSG Rules - for <desc>` (per detected scope) |
| the description text fields | edited in place — step 5 |
| `Custom.ApprovedDeploymentDate` | window start, step 6 |
| `Custom.ApproveddeploymentEndTime` | window end, step 6 (casing is irregular; use it verbatim) |
| `System.AssignedTo` | the creating user |
| `Custom.Primary` | the creating user |

Two more things are always fresh but are **relations, not fields** — they are added via
`/relations/-` patch entries in step 8, not folded into `$freshFields`:

- the parent relation, from step 1
- the PR `ArtifactLink` relation(s), from step 2

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

When the clone is an exact-scope match, its scope-worded fields (the impacted-services
field, the short-description field, the reason-for-change field, the CAB document
folder's intro line) are already correct for this change — do not branch or rewrite them.
Where a cloned value looks wrong for the scope regardless (the impacted-services field
saying `Azure Firewall` on an NSG change is the known case), surface it in step 7's table
for eyeballing — copying it forward is the specified behaviour, not a bug to patch here.

When the clone came from the any-scope fallback (step 3), or the detected scope is
`both` and the clone is single-scope, those same scope-worded fields describe the
**clone's** scope, not necessarily the detected one — there is no cloned or invented
value that correctly names a scope the clone never covered. Do not rewrite them to insert
a corrected scope word; that is writing a field value, which this skill never does. Flag
the mismatch explicitly in step 7's table instead, naming which fields carry the clone's
own scope wording, so the user can hand-edit them before go-ahead.

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

Show the full resolved field table: title, detected scope (and whether it was detected
from a PR diff or **inferred** from conversation/PR-title convention — step 2), the
matched RFC's ID and title (so the clone source is auditable, and whether it was an
**exact-scope match or an any-scope fallback** — step 3), the edited description fields
with their changes visible, any cloned field flagged as carrying the **clone's own scope
wording** rather than the detected scope (step 4), the deployment window in local **and**
UTC, the parent work item ID/title, every linked PR ID (step 2), the resolved
`System.AssignedTo`/`Custom.Primary`, and every cloned field being carried forward.

Wait for explicit go-ahead. An implied "looks fine" is not go-ahead — get a clear yes.

### 8. Create the RFC in one JSON-patch document

**Do not use `az boards work-item create --fields`.** All required fields must be present
at save time — the RFC template rejects a partial create, so fields cannot be split into a
later PATCH. And some cloned values are SharePoint URLs containing `&`: passed as
`--fields` command-line arguments, the `az.cmd` → `cmd.exe` wrapper on Windows treats the
unescaped `&` as a command separator and the create fails with garbage
`'file' is not recognized...` errors.

Both problems disappear by building **one** JsonPatchDocument holding every field, the
parent relation, and **one `ArtifactLink` relation per linked PR** from step 2's list,
written to a file so no value ever reaches the command line:

```powershell
function P($field, $value) { @{ op = "add"; path = "/fields/$field"; value = $value } }

# $cloneFields = the copy-verbatim set from step 4; $freshFields = the forced-fresh field
# values only (the step-4 table) — the parent and PR relations are NOT in $freshFields,
# they are added below as their own /relations/- patch entries.

# One ArtifactLink relation per linked PR (step 2's list) - get each PR's artifactId first:
#   az repos pr show --id <prId> --query artifactId -o tsv --org https://dev.azure.com/HollardInsuranceRetail
$prRelations = foreach ($prArtifactId in $prArtifactIds) {
    @{ op = "add"; path = "/relations/-"; value = @{
        rel        = "ArtifactLink"
        url        = $prArtifactId
        attributes = @{ name = "Pull Request" }
      }
    }
}

$patch = @(
  $cloneFields.GetEnumerator() | ForEach-Object { P $_.Key $_.Value }
  $freshFields.GetEnumerator() | ForEach-Object { P $_.Key $_.Value }
  @{ op = "add"; path = "/relations/-"; value = @{
      rel = "System.LinkTypes.Hierarchy-Reverse"
      url = "https://dev.azure.com/HollardInsuranceRetail/_apis/wit/workItems/$parentId"
    }
  }
  $prRelations
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

**If you ever need to PATCH an *existing* RFC by id** (not at creation) — e.g. adding a PR
link after the fact — `az devops invoke --route-parameters id=<id>` is **broken** for the
`workitems` resource: the extension resolves the resource/area pair to a single location
and always picks the create-by-type template, which then throws `KeyError: 'type'`
regardless of what route parameters you pass (confirmed across `--api-version`
1.0/3.0/7.1 — genuinely only one location is registered for this resource+area in this az
CLI version). Use `az rest` instead, which isn't affected:

```powershell
az rest --method patch `
  --url "https://dev.azure.com/HollardInsuranceRetail/TSC Change Control/_apis/wit/workitems/<id>?api-version=7.1" `
  --resource 499b84ac-1321-427f-aa17-267ca6975798 `
  --headers "Content-Type=application/json-patch+json" `
  --body "@<patch file path>"
```

`--resource 499b84ac-1321-427f-aa17-267ca6975798` is the well-known Azure DevOps AAD app
ID — without it `az rest` defaults to an ARM-audience token, which Azure DevOps rejects.

This PATCH path is not exempt from the create path's safeguards: it still needs step 7's
explicit go-ahead before running, and step 9's read-back validation after — re-`show` the
item and diff it against what was intended.

Leave the new item in its default initial state — do **not** transition it toward Complete
or any other state. That workflow step is always manual.

### 9. Validate the write

Immediately after the create, read the new item back and diff it against the intended
field table from step 7 — including the parent relation and every PR `ArtifactLink`:

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
| Query matched the wrong-scope RFC | Match the full title prefix for the detected scope; a shortened `CONTAINS` also matches one of the other two titles |
| Scope query filtered on the impacted-services field | That field said `Azure Firewall` even on NSG-only RFCs; only the title discriminates |
| No exact-scope RFC found, so the query stopped | Fall back to any-scope (step 3), flagged as inferred in step 7 — hard-stop only once any-scope is exhausted too |
| A clone's scope-worded field got rewritten to match the detected scope | Flag the mismatch in step 7 instead — step 4 forbids writing a corrected scope value |
| Only the first linked PR got attached to the RFC | Every linked PR gets its own `ArtifactLink` relation — step 2 keeps the full list, step 8 loops over it |
| A CAB document field was regenerated and lost its SOP links | Edit only that field's intro line; the links exist nowhere else to restore from |
| Create attempted with `--fields` | One JSON-patch document via `--in-file`; `&` in cloned URLs breaks `--fields` on Windows |
| PATCH attempted via `az devops invoke --route-parameters id=<id>` | Broken for the `workitems` resource — use `az rest` instead (step 8) |
| Success reported before reading the item back | Step 9's diff runs before step 10's URL, every time |

## Adding a new RFC subtype

Use this checklist to build support for a new RFC type (a different BAU RFC type, a
non-BAU RFC, or another org) the same way this skill's BAU firewall/NSG path was built —
never by inventing field values from guesswork.

1. **Sample real completed RFCs of the new subtype.** Pull N (at least 10–12, matching
   how this skill's field set was derived) completed RFCs of the target subtype via
   `az boards work-item show`, assigned to the invoking user where possible.
2. **Find the title-prefix scope discriminator.** Confirm the new subtype has an
   equivalent full-title-prefix pattern that reliably separates it from every other RFC
   type/scope this skill already handles — re-derive it from the sampled titles, don't
   assume it looks like the firewall/NSG prefixes.
3. **Classify every field** the sampled RFCs share as one of: **forced-fresh** (must be
   computed or supplied per run — title, description specifics, deployment window,
   identity fields, relations), **copy-verbatim** (identical or near-identical across
   every sample, safe to clone from the matched prior RFC), or **dropped** (system-managed
   fields a create rejects, per step 4's dropped list).
4. **Confirm no sampled value ever gets written into this file.** Every literal observed
   while sampling — including innocuous-looking picklist values — stays out of the
   skill's prose and code blocks; the runtime clone (steps 3–4's mechanism) supplies it,
   exactly as it does for the firewall/NSG path.
5. **Route it.** Add the new invocation form to the Routing section above with its own
   bullet, pointing at a new steps section (or an extension of the existing one, if the
   mechanics are shared) — don't fold an untested subtype into the firewall/NSG steps
   silently.
6. **Verify against one real created RFC** before calling the subtype implemented, the
   same way both-scope and multi-PR support required a real run before this file could
   describe them as handled.

## Not implemented

- Non-BAU RFCs (`/rfc <description>`), other BAU RFC types (`/rfc bau <other-type>`), and
  other Azure DevOps organisations.

Each needs its own field-pattern research against real completed RFCs before it can be
templated — see "Adding a new RFC subtype" above. Do not invent field values for these
paths.
