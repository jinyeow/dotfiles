---
description: Draft and create a new PBI from a plain-language description. Structures it with title, description, acceptance criteria, tags, and story points before writing to Azure Boards.
---

# New PBI

Load this skill's `SKILL.md` (azure-boards-organiser) and resolve config (see SKILL.md → Configuration).

If an Azure DevOps MCP server is connected this session, use its tools for all reads/writes; otherwise use the PowerShell `az` blocks below (see SKILL.md → Execution backend).

```powershell
$cfg = Get-Content "$HOME/.claude/skills/azure-boards-organiser/config.json" -Raw | ConvertFrom-Json
```
If `config.json` is missing, stop and tell the user to copy `config.example.json`.

## Usage
```
/new-pbi "<plain language description of the work>"
```

Example:
```
/new-pbi "We need to enforce tagging on all resource groups in the landing zone using Azure Policy"
```

---

## Step 1: Draft the PBI

From the user's input, generate a structured PBI draft. Apply the quality rules from `SKILL.md` from the start — do not produce a draft that would fail Phase 2 of `/prepare-pbi`.

### Title
Write a specific, action-oriented title (more than 5 words, no vague terms).

### Description
```
## Context
<Why this work is needed>

## Scope
<What is in scope / out of scope>

## References
<Known related items, ADRs, docs — or "TBC" if unknown>
```

### Acceptance Criteria
Generate 3–5 specific, testable criteria:
```
- [ ] Given <precondition>, when <action>, then <expected outcome>
```

### Story Point Estimate
Suggest a Fibonacci estimate (1, 2, 3, 5, 8, 13) with a brief rationale.

### Tags
Suggest relevant tags from `$cfg.tags`.

### Area Path
Ask the user which Area Path to use, or default to `$cfg.areaPathDefault`.

### Iteration Path
Ask: "Which sprint should this go into?" Options:
- Current sprint:
  ```powershell
  az boards iteration team list --team $cfg.team --project $cfg.project --timeframe current --query '[0].name' -o tsv
  ```
- Next sprint
- Backlog (no sprint yet) — set the iteration to `$cfg.iterationRoot` (the root that grooming queries scope `UNDER`), **not** the bare project root, or the PBI won't appear in `/prioritize-backlog` or `/find-stale`.

---

## Step 2: Review

Present the full draft for review:

```
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
 NEW PBI DRAFT
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
 Title:       Enforce mandatory resource group tagging via Azure Policy

 Description:
   ## Context
   ...

 Acceptance Criteria:
   - [ ] Given a resource group is created without required tags...
   - [ ] Policy compliance report shows 0 non-compliant RGs in...

 Story Points: 5  (rationale: new policy definition + remediation task)
 Priority:     2 (High)
 Tags:         azure-policy; landing-zone; cost-management
 Area Path:    <areaPathDefault>
 Iteration:    Backlog
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
```

Ask: **"Create this PBI? (yes / edit / cancel)"**

If "edit": ask what to change and regenerate the affected section only.

---

## Step 3: Create in ADO

Escape `& < >` in the Description and Acceptance Criteria text, then wrap in `<p>` / `<ul><li>` (see SKILL.md → HTML field handling). Pass `--fields` as an array of `Name=Value` strings — never comma-joined. Never set `BacklogPriority` manually.
```powershell
$fields = @(
  'Microsoft.VSTS.Scheduling.StoryPoints=5'
  'Microsoft.VSTS.Common.Priority=2'
  'Microsoft.VSTS.Common.AcceptanceCriteria=<ul><li>Given X, when Y, then Z</li></ul>'
  'System.Description=<p>Context...</p>'
  'System.Tags=azure-policy; landing-zone; cost-management'
)
$azArgs = @(
  'boards','work-item','create'
  '--project', $cfg.project
  '--title','Enforce mandatory resource group tagging via Azure Policy'
  '--type','Product Backlog Item'
  '--area', $cfg.areaPathDefault
  '--iteration', $cfg.iterationRoot   # backlog (groomable); or "$($cfg.iterationRoot)\<SprintName>" for a sprint
  '--fields'
) + $fields
$created = az @azArgs -o json | ConvertFrom-Json
```

Output the created work item ID and a direct URL (resolve org from `az devops configure --list`):
```
✅ Created PBI #<ID>: <Title>
   https://dev.azure.com/<ORG>/<project>/_workitems/edit/<ID>
```

---

## Step 4: Offer next actions

- `"Add tasks"` → run the task generation phase from `/prepare-pbi`
- `"Create another PBI"` → restart from Step 1
- `"Prioritize backlog"` → run `/prioritize-backlog`
