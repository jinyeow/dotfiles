---
description: Split an oversized or vague Azure Boards PBI into child PBIs (decomposition) or sibling replacement PBIs (supersede), partitioning the Acceptance Criteria and Fibonacci-estimating each piece.
---

# Split PBI

Load this skill's `SKILL.md` (azure-boards-organiser) and resolve config (see SKILL.md → Configuration):

```powershell
$cfg = Get-Content "$HOME/.claude/skills/azure-boards-organiser/config.json" -Raw | ConvertFrom-Json
$org = $cfg.org
if (-not $org) { throw "config.json has no 'org'. Copy config.example.json and set it to your organisation URL." }
```

`--organization $org` goes on every call and is **not** optional: this machine has no `az devops` default
organisation, so omitting it fails with `--organization must be specified`. `--org` is not accepted by
`az boards query` either — it fails the same misleading way. If `config.json` is missing, **stop** and tell
the user to copy `config.example.json` (see SKILL.md → Configuration) — do not guess team/iteration values.

If an Azure DevOps MCP server is connected this session, use its tools for all reads/writes; otherwise use the PowerShell `az` blocks below.

## Usage
```
/split-pbi <ID>
```
Optionally append:
- `--dry-run`   Show the proposed split without creating anything in ADO.

---

## Step 1: Fetch the PBI

```powershell
$wi = az boards work-item show --id $Id --organization $org -o json | ConvertFrom-Json
```

Strip HTML tags from Description and Acceptance Criteria for display. Show: ID, Title, State, Story Points, Tags, Area Path, Iteration Path, Parent, Description, Acceptance Criteria.

If the work item is not a `Product Backlog Item` or `Bug`, **stop** and tell the user.

**Size gate**: if Story Points <= 8 **and** the scope reads as coherent (single deliverable, AC all point at one outcome), say so plainly and ask whether to split anyway before continuing. A well-sized, coherent PBI is not worth splitting.

---

## Step 2: Check for existing children (idempotency)

Before proposing anything, run the flat **Children of a PBI — flat single-parent** query (see `references/wiql-patterns.md` → Work Item Links) to see whether this PBI was already split:

```powershell
$childWiql = @"
SELECT [System.Id], [System.Title], [System.State]
FROM WorkItems
WHERE [System.Parent] = $Id
  AND [System.WorkItemType] = 'Product Backlog Item'
  AND [System.State] <> 'Removed'
"@ -replace '\s*\r?\n\s*', ' '   # double-quoted so $Id interpolates; filter to child PBIs only
$childPbis = az boards query --wiql $childWiql --project $cfg.project --organization $org -o json | ConvertFrom-Json
```

If `$childPbis` is non-empty, **warn the user and ask** whether to add to them or stop — do not duplicate an existing split. The query filters to child *PBIs* only, so existing child Tasks (from `/prepare-pbi`) never falsely block a split.

---

## Step 3: Choose the split mode

Present **both** options and recommend one:

- **Child PBIs (decompose)** — the new PBIs become children of the original (parented via a `parent` relation, see Step 5). Recommend when the original is itself a deliverable/umbrella that should survive as a container (e.g. a Feature-like PBI, or one whose title still describes the whole).
- **Sibling replacement PBIs (supersede)** — the new PBIs sit beside the original and **replace** it; the original is then closed out. Recommend when the original is just an oversized placeholder that no longer describes any single shippable outcome.

Recommend based on whether the original is itself a deliverable. State the recommendation and reason in one line; let the user pick.

---

## Step 4: Propose the split

Generate 2–4 new PBIs. Each gets:

- **Title** — specific and action-oriented (what, not how); avoids "fix", "update", "misc".
- **Description** — structured as:
  ```
  ## Context
  <Why this slice is needed — the driver carved out of the original>

  ## Scope
  <What is in scope for this PBI; what is explicitly out (covered by a sibling)>

  ## References
  <Original PBI #<ID>, plus any linked items/ADRs/resources>
  ```
- **Acceptance Criteria** — a **partition** of the original AC: assign each original criterion to exactly one new PBI, adding criteria only where a slice genuinely needs one. Do not copy the full AC into every child.
- **Story Points** — a Fibonacci estimate (1, 2, 3, 5, 8, 13), each strictly **less than** the original, summing roughly to the original's points. Briefly justify each.
- **Tags / Area Path / Iteration Path** — inherited from the original (`$wi`).

Present the proposal as a table:

```
#  PROPOSED TITLE                                   PTS  AC ITEMS  TAGS
─────────────────────────────────────────────────────────────────────────
1  Configure hub VNet peering for spoke egress       5   AC 1,2    networking; bicep
2  Add Azure Firewall rules for spoke outbound       3   AC 3,4    networking; security
                                                     ──
                                          sum = 8  (original = 8)
```

Confirm: **"Create this split? (yes / no / edit)"**

---

## Step 5: Create (on confirm, not `--dry-run`)

HTML-encode Description and Acceptance Criteria before writing via CLI: escape `&` → `&amp;`, `<` → `&lt;`, `>` → `&gt;` in text **first**, then wrap paragraphs in `<p>…</p>` and bullet/criteria lines in `<ul><li>…</li></ul>`. Keep values single-quoted.

**Child mode** — create each new PBI parented to the original:

```powershell
$fields = @(
  'Microsoft.VSTS.Scheduling.StoryPoints=5'
  'Microsoft.VSTS.Common.AcceptanceCriteria=<ul><li>Given X, when Y, then Z</li></ul>'
  'System.Description=<p>## Context …</p>'
  "System.Tags=$($wi.fields.'System.Tags')"
)
$azArgs = @(
  'boards','work-item','create'
  '--project', $cfg.project
  '--title','Configure hub VNet peering for spoke egress'
  '--type','Product Backlog Item'
  '--area', $wi.fields.'System.AreaPath'
  '--iteration', $wi.fields.'System.IterationPath'
  '--organization', $org
  '--fields'
) + $fields
$created = az @azArgs -o json | ConvertFrom-Json
# Parent the child PBI to the original via a relation (System.Parent is read-only — use relation add, not --fields):
az boards work-item relation add --id $created.id --relation-type parent --target-id $Id --organization $org -o json | ConvertFrom-Json | Out-Null
```

**Replacement mode** — create each new PBI as a sibling (same parent as the original, if any), then link it back to the original as Related:

```powershell
# Create the sibling (carry the original's parent if it has one)
$fields = @(
  'Microsoft.VSTS.Scheduling.StoryPoints=5'
  'Microsoft.VSTS.Common.AcceptanceCriteria=<ul><li>…</li></ul>'
  'System.Description=<p>## Context …</p>'
  "System.Tags=$($wi.fields.'System.Tags')"
)
$azArgs = @(
  'boards','work-item','create'
  '--project', $cfg.project
  '--title','Add Azure Firewall rules for spoke outbound'
  '--type','Product Backlog Item'
  '--area', $wi.fields.'System.AreaPath'
  '--iteration', $wi.fields.'System.IterationPath'
  '--organization', $org
  '--fields'
) + $fields
$created = az @azArgs -o json | ConvertFrom-Json

# Carry the original's parent, if any (System.Parent is read-only — relation add, not --fields):
if ($wi.fields.'System.Parent') {
  az boards work-item relation add --id $created.id --relation-type parent --target-id $wi.fields.'System.Parent' --organization $org -o json | ConvertFrom-Json | Out-Null
}

# Link the new PBI back to the original as Related
$azArgs = @(
  'boards','work-item','relation','add'
  '--id', $created.id
  '--relation-type','Related'
  '--target-id', $Id
  '--organization', $org
)
az @azArgs -o json | ConvertFrom-Json | Out-Null
```

For **replacement mode**, after creating all siblings, **offer** to set the original's `System.State=Removed` with a note (do not do it unprompted):

```powershell
# $newIds: collect each sibling's $created.id from the creates above (e.g. $newIds += $created.id).
# $encodedOriginalDesc: the original's existing Description ($wi.fields.'System.Description', already HTML) — append, don't re-escape.
$fields = @('System.State=Removed', "System.Description=$encodedOriginalDesc<p>Superseded by #$($newIds -join ', #').</p>")
$azArgs = @('boards','work-item','update','--id', $Id, '--fields') + $fields + @('--organization', $org)
az @azArgs -o json | ConvertFrom-Json | Out-Null
```

> Do **not** set BacklogPriority manually — let the team's stack rank place the new items.

---

## Step 6: Report and offer next actions

Output a table of created IDs + URLs (`$created.id`, `$created._links.html.href`). Then offer next actions:

- Run `/prepare-pbi <newID>` on each new PBI to enrich and generate Tasks.
- (Replacement mode) Set the original to Removed if not already done.
- `/prioritize-backlog` to slot the new PBIs into a sprint.

---

## Error Handling

- **Work item not found**: show the `az boards` error and stop.
- **Auth error**: remind the user to run `az login` and `az devops configure --defaults organization=https://dev.azure.com/<ORG>`.
- **HTML write failure**: retry with content re-escaped (`& < >`) and wrapped in `<p>`/`<ul><li>`.
- **Relation add rejected** (replacement mode): report the error; the PBIs are still created — re-link manually or via MCP.
