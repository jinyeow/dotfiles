---
description: Analyse, enrich, and optionally decompose an Azure Boards PBI. Fetches the work item, scores it against quality criteria, fills gaps, and generates child Tasks.
---

# Prepare PBI

Load this skill's `SKILL.md` (azure-boards-organiser) and resolve config (see SKILL.md → Configuration).

If an Azure DevOps MCP server is connected this session, use its tools for all reads/writes; otherwise use the PowerShell `az` blocks below (see SKILL.md → Execution backend).

```powershell
$cfg = Get-Content "$HOME/.claude/skills/azure-boards-organiser/config.json" -Raw | ConvertFrom-Json
```
If `config.json` is missing, stop and tell the user to copy `config.example.json`.

## Usage
```
/prepare-pbi <PBI_ID>
```
Optionally append flags:
- `--tasks`      Also generate child Tasks after enriching
- `--dry-run`    Show proposed changes without writing back to ADO

---

## Phase 1: Fetch PBI

1. Fetch the full work item (parse JSON, never text):
   ```powershell
   $wi = az boards work-item show --id $Id -o json | ConvertFrom-Json
   ```
   Extract and display the following fields (strip HTML tags from Description and Acceptance Criteria for readability):
   - ID, Title, State, Area Path, Iteration Path
   - Story Points (`Microsoft.VSTS.Scheduling.StoryPoints`)
   - Priority (`Microsoft.VSTS.Common.Priority`)
   - Tags (`System.Tags`)
   - Description (`System.Description`)
   - Acceptance Criteria (`Microsoft.VSTS.Common.AcceptanceCriteria`)
   - Parent (if any)

2. **If the work item is not a `Product Backlog Item` or `Bug`, stop** and tell the user.

---

## Phase 2: Quality Analysis

Score the PBI against these criteria and output a checklist. Mark each ✅ (pass) or ❌ (fail/missing):

### Title
- [ ] More than 5 words
- [ ] Describes **what**, not **how**
- [ ] No vague terms: "fix", "update", "misc", "changes", "improvements", "stuff"

### Description
- [ ] Non-empty
- [ ] Contains **what** needs doing
- [ ] Contains **why** (business value or technical rationale)

### Acceptance Criteria
- [ ] Non-empty
- [ ] At least 2 specific, testable criteria
- [ ] Written as Given/When/Then or clear bullet points
- [ ] No trivially obvious criteria present ("deployment succeeds", "no errors in logs", "code is committed")

### Sizing & Scheduling
- [ ] Story Points assigned and > 0
- [ ] Iteration Path set (not left at project root)
- [ ] Area Path reflects correct team or component

### Tags
- [ ] At least one tag assigned

**If 3 or more criteria fail: stop here**, output the checklist with recommendations, and ask the user whether to proceed with enrichment anyway. A poorly defined PBI is not worth decomposing.

---

## Phase 3: Enrichment

For each failing criterion, propose improved content. Apply the following transformation rules:

### Title
Rewrite to be action-oriented and specific:
- Bad: `"Update network config"`
- Good: `"Configure hub VNet peering to enforce spoke egress through Azure Firewall"`

### Description
Structure as:
```
## Context
<Why this work is needed — business or technical driver>

## Scope
<What is in scope. What is explicitly out of scope if relevant.>

## References
<Links to relevant ADO items, ADRs, docs, or Azure resource IDs if known>
```

### Acceptance Criteria
Generate specific, testable criteria in this format:
```
- [ ] Given <precondition>, when <action>, then <expected outcome>
- [ ] <Resource type> in <environment> has <property> = <expected value>
- [ ] Pipeline <name> completes successfully with exit code 0
- [ ] No policy compliance drift detected after deployment (Azure Policy compliance = Compliant)
```
Remove any existing trivially obvious criteria.

### Tags
Suggest tags from `$cfg.tags` based on the PBI content.

### Story Points
If unpointed, suggest a story point estimate based on scope and complexity. Use Fibonacci: 1, 2, 3, 5, 8, 13. Briefly justify the estimate.

### Iteration Path
If unset or at root, ask the user which sprint to assign, or suggest the current sprint.

---

## Phase 4: Confirm and Write Back

Present a diff-style summary of all proposed changes:

```
FIELD                  CURRENT          → PROPOSED
─────────────────────────────────────────────────────────────────
Title                  "Update config"  → "Configure hub VNet peering..."
Story Points           (empty)          → 5
Tags                   (empty)          → "networking; bicep; landing-zone"
Acceptance Criteria    (empty)          → [see below]
Iteration Path         CloudPlatform    → CloudPlatform\Team\Sprint 42
```

Ask: **"Apply these changes? (yes / no / select fields)"**

If confirmed (and not `--dry-run`), write back each changed field. Escape `& < >` in any HTML field value, then wrap in `<p>` / `<ul><li>` (see SKILL.md → HTML field handling). Pass `--fields` as an array of `Name=Value` strings — never comma-joined:
```powershell
$fields = @(
  'System.Title=Configure hub VNet peering to enforce spoke egress through Azure Firewall'
  'Microsoft.VSTS.Scheduling.StoryPoints=5'
  'System.Tags=networking; bicep; landing-zone'
  'Microsoft.VSTS.Common.AcceptanceCriteria=<ul><li>Given X, when Y, then Z</li></ul>'
  "System.IterationPath=$($cfg.iterationRoot)\Sprint 42"
)
$azArgs = @('boards','work-item','update','--id', $Id, '--fields') + $fields
az @azArgs -o json | ConvertFrom-Json | Out-Null
```

> Never set `BacklogPriority` manually.

---

## Phase 5: Task Generation (if `--tasks` flag or user requests)

Break the enriched PBI into implementation Tasks. Each task must have:

```
## Task N: <Short imperative title>
Area:      <Same Area Path as parent PBI>
Iteration: <Same Iteration Path as parent PBI>
Remaining Work: <Estimated hours — decimal, e.g. 4.0>
Activity:  <Development | Testing | Documentation | Deployment | Design>

Steps:
- <Concrete action 1>
- <Concrete action 2>

Verification:
- <How to confirm this task is done — ideally a CLI command or observable state>
```

**Sequencing rules:**
1. Infrastructure / IaC changes first
2. Code / configuration changes second
3. Testing and validation third
4. Documentation last

### Idempotency guard

Before creating any child Task, fetch the PBI's existing child Tasks and skip/flag any proposed task whose title already exists. A flat single-parent query (`[System.Parent] = <ID>`) returns child fields directly — simpler and more robust than a `WorkItemLinks` query (no target-resolution), and a single literal parent ID is a field match, not a subquery:
```powershell
$childWiql = @"
SELECT [System.Id], [System.Title], [System.State]
FROM WorkItems
WHERE [System.Parent] = $Id
  AND [System.WorkItemType] = 'Task'
  AND [System.State] <> 'Removed'
"@   # double-quoted here-string so $Id interpolates; no other $ in the query
$existingTitles = az boards query --wiql $childWiql --project $cfg.project -o json |
  ConvertFrom-Json | ForEach-Object { $_.fields.'System.Title' }
```

Compare proposed task titles against `$existingTitles` (case-insensitive). Present a **dry-run table** marking each task `CREATE` or `SKIP (exists)`, then confirm before writing:
```
PROPOSED TASKS (parent PBI #<ID>)
──────────────────────────────────────────────────
ACTION  TITLE                                   Hours  Activity
CREATE  Author Bicep module for VNet peering    4.0    Development
SKIP    Run what-if and validate                 —     (already exists)
```

After the user confirms, create only the `CREATE` tasks as children of the PBI:
```powershell
$fields = @(
  'Microsoft.VSTS.Scheduling.RemainingWork=4'
  'Microsoft.VSTS.Common.Activity=Development'
)
$azArgs = @(
  'boards','work-item','create'
  '--project', $cfg.project
  '--title','Author Bicep module for VNet peering'
  '--type','Task'
  '--area', $wi.fields.'System.AreaPath'        # inherit the parent PBI's Area Path
  '--iteration', $wi.fields.'System.IterationPath'  # inherit the parent PBI's Iteration
  '--fields'
) + $fields
$created = az @azArgs -o json | ConvertFrom-Json
# Parent the Task to the PBI via a relation — System.Parent is read-only; set it with relation add, not --fields:
az boards work-item relation add --id $created.id --relation-type parent --target-id $Id -o json | ConvertFrom-Json | Out-Null
```

Output a summary table of created Task IDs on completion.

---

## Error Handling

- **Work item not found**: Display the error from `az boards` and stop.
- **Auth error**: Remind the user to run `az login` and check `az devops configure --list`.
- **HTML write failure**: Retry with content escaped (`& < >`) and wrapped in `<p>` tags.

---

## Offer next actions

- `"Generate tasks"` → run Phase 5 if not already done
- `"Move PBI to Done"` → `/move-to-done <ID>`
- `"Show my sprint work"` → `/my-sprint-work`
- `"Prioritize backlog"` → `/prioritize-backlog`
