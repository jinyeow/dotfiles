---
description: Show my PBIs and their child Tasks in the current sprint (the PBI breakdown), with state, story points, and time tracking.
---

# My Sprint Work

Load this skill's `SKILL.md` (azure-boards-organiser) and resolve config (see SKILL.md → Configuration).

If an Azure DevOps MCP server is connected this session, use its tools for all reads/writes; otherwise use the PowerShell `az` blocks below (see SKILL.md → Execution backend).

```powershell
$cfg = Get-Content "$HOME/.claude/skills/azure-boards-organiser/config.json" -Raw | ConvertFrom-Json
```
If `config.json` is missing, stop and tell the user to copy `config.example.json`.

## Step 1: Get current sprint name

```powershell
$azArgs = @(
  'boards','iteration','team','list'
  '--team', $cfg.team
  '--project', $cfg.project
  '--timeframe','current'
  '--query','[0].{name:name,path:path}'
  '-o','json'
)
$sprint = az @azArgs | ConvertFrom-Json
```

## Step 2: Query my PBIs

Run the "My incomplete PBIs in current sprint" WIQL from `references/wiql-patterns.md`:
```powershell
$wiql = @'
SELECT [System.Id], [System.Title], [System.State],
       [Microsoft.VSTS.Scheduling.StoryPoints]
FROM WorkItems
WHERE [System.WorkItemType] = 'Product Backlog Item'
  AND [System.AssignedTo] = @Me
  AND [System.IterationPath] = @CurrentIteration('[<PROJECT>]\<TEAM>')
  AND [System.State] NOT IN ('Done', 'Removed')
ORDER BY [Microsoft.VSTS.Common.BacklogPriority]
'@ -replace '<PROJECT>', $cfg.project -replace '<TEAM>', $cfg.team
$pbis = az boards query --wiql $wiql --project $cfg.project -o json | ConvertFrom-Json
```

## Step 3: Query the child Tasks of my PBIs

> **Scope**: this is the breakdown of *your* PBIs — it returns all child Tasks of those PBIs regardless of assignee, and does **not** include Tasks assigned to you under other people's PBIs. For an assignee-centric view (everything assigned to `@Me`), use `/daily-standup`.

WIQL has no subqueries, so use the **two-step literal-ID approach (preferred)**: collect the PBI IDs from Step 2 (`$pbis`), then run one flat query filtered to their child Tasks. A flat query returns task fields directly — no per-target resolution:
```powershell
$pbiIds = ($pbis | ForEach-Object { $_.id }) -join ', '
if ($pbiIds) {
  $taskWiql = @"
SELECT [System.Id], [System.Title], [System.State], [System.AssignedTo],
       [System.Parent],
       [Microsoft.VSTS.Scheduling.RemainingWork],
       [Microsoft.VSTS.Scheduling.CompletedWork]
FROM WorkItems
WHERE [System.WorkItemType] = 'Task'
  AND [System.Parent] IN ($pbiIds)
  AND [System.State] <> 'Removed'
"@   # double-quoted so $pbiIds interpolates
  $tasks = az boards query --wiql $taskWiql --project $cfg.project -o json | ConvertFrom-Json
}
```
If `$pbis` is empty, skip this step.

**Alternative (MCP/REST only)**: the "Tasks under my PBIs … (WorkItemLinks)" pattern in `references/wiql-patterns.md` returns link relations directly — but `az boards query` is flat-only, so it runs only via the MCP server or REST. The flat two-step above is the CLI path and is preferred.

## Step 4: Output

Present as two sections:

### 📋 My PBIs — <SprintName>

| ID | Title | State | Points | Time Spent (h) |
|----|-------|-------|--------|----------------|
| ... | ... | ... | ... | ... |

> **Time Spent** is per-PBI rolled up from child Tasks: sum `$tasks` `CompletedWork` grouped by `System.Parent` (PBIs don't carry `CompletedWork` in Scrum).

**Totals (incomplete only)**: N PBIs, X story points remaining; Z hours logged / W hours remaining (summed from child Tasks). *This view fetches only non-Done PBIs — for committed-vs-done velocity, use `/sprint-summary`.*

### ✅ Tasks under my PBIs

Group tasks under their parent PBI:

```
[PBI 1234] Configure hub VNet peering
  ├── [Task 1235] Update Bicep module — Committed — 2h remaining
  └── [Task 1236] Run what-if and validate — New — 1h remaining

[PBI 1240] Implement DINE policy for diagnostic settings
  └── [Task 1241] Author policy definition — In Progress — 3h remaining / 1.5h logged
```

## Step 5: Offer next actions

After the summary, offer:
- `"Prepare a PBI"` → suggest running `/prepare-pbi <ID>`
- `"Log time on a task"` → update `CompletedWork` and `RemainingWork` on a Task
- `"Move a PBI to Done"` → update State
- `"Show sprint summary"` → suggest running `/sprint-summary`
