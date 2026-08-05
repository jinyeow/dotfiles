---
description: Sprint health snapshot — velocity, completion rate, unpointed items, and backlog quality flags.
---

# Sprint Summary

Load this skill's `SKILL.md` (azure-boards-organiser) and resolve config (see SKILL.md → Configuration).

If an Azure DevOps MCP server is connected this session, use its tools for all reads/writes; otherwise use the PowerShell `az` blocks below (see SKILL.md → Execution backend).

```powershell
$cfg = Get-Content "$HOME/.claude/skills/azure-boards-organiser/config.json" -Raw | ConvertFrom-Json
$org = $cfg.org
if (-not $org) { throw "config.json has no 'org'. Copy config.example.json and set it to your organisation URL." }
```
`--organization $org` goes on every call and is **not** optional: this machine has no `az devops` default
organisation, so omitting it fails with `--organization must be specified`. `--org` is not accepted by
`az boards query` either — it fails the same misleading way. If `config.json` is missing, stop and tell the
user to copy `config.example.json` to `config.json` and fill it in.

Accepts an optional sprint name argument: `/sprint-summary <SprintName>`. Resolve it once and reuse it in the queries below:
```powershell
# $SprintName: the /sprint-summary argument if one was given; otherwise the current sprint:
if (-not $SprintName) {
  $SprintName = az boards iteration team list --team $cfg.team --project $cfg.project --organization $org --timeframe current --query '[0].name' -o tsv
}
```

## Step 1: Fetch sprint items

Query all PBIs and Bugs in the target sprint (all states except Removed).
Use the "Sprint velocity summary" WIQL from `references/wiql-patterns.md`:
```powershell
$wiql = @'
SELECT [System.Id], [System.State], [Microsoft.VSTS.Scheduling.StoryPoints]
FROM WorkItems
WHERE [System.WorkItemType] IN ('Product Backlog Item', 'Bug')
  AND [System.IterationPath] = '<iterationRoot>\<SprintName>'
  AND [System.State] <> 'Removed'
'@ -replace '<iterationRoot>', $cfg.iterationRoot -replace '<SprintName>', $SprintName -replace '\s*\r?\n\s*', ' '
$items = az boards query --wiql $wiql --project $cfg.project --organization $org -o json | ConvertFrom-Json
```

Also fetch all Tasks in the sprint for time tracking totals:
```powershell
$taskWiql = @'
SELECT [System.Id], [System.State], [System.AssignedTo], [System.Parent],
       [Microsoft.VSTS.Scheduling.RemainingWork],
       [Microsoft.VSTS.Scheduling.CompletedWork]
FROM WorkItems
WHERE [System.WorkItemType] = 'Task'
  AND [System.IterationPath] = '<iterationRoot>\<SprintName>'
  AND [System.State] <> 'Removed'
'@ -replace '<iterationRoot>', $cfg.iterationRoot -replace '<SprintName>', $SprintName -replace '\s*\r?\n\s*', ' '
$tasks = az boards query --wiql $taskWiql --project $cfg.project --organization $org -o json | ConvertFrom-Json
```

## Step 2: Compute metrics

Calculate:
- **Committed points**: sum of StoryPoints for all PBIs/Bugs in sprint
- **Completed points**: sum of StoryPoints where State = 'Done'
- **Completion rate**: completed / committed × 100%
- **Remaining points**: committed − completed
- **Unpointed items**: count of PBIs/Bugs with StoryPoints = 0 or empty
- **Total hours logged**: sum of CompletedWork across all Tasks
- **Total hours remaining**: sum of RemainingWork across all Tasks

## Step 3: Output

```
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
 SPRINT SUMMARY  <SprintName>
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
 Committed       XX pts across N items
 Done            XX pts (XX%)
 Remaining       XX pts
 Unpointed       N items ⚠️ (if > 0)

 Hours logged    XXh
 Hours remaining XXh

 State breakdown:
   New           N items  (X pts)
   Approved      N items  (X pts)
   Committed     N items  (X pts)
   Done          N items  (X pts)
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
```

### Items at risk
Flag any item that is:
- State = Committed with RemainingWork = 0 on all child Tasks AND State ≠ Done (group `$tasks` by `System.Parent` to roll RemainingWork up to each PBI)
- State = New with no story points and no Tasks
- Story Points > 8 (likely needs splitting)

## Step 4: Backlog health check (bonus)

Run the "Unpointed PBIs in backlog" and "PBIs missing Acceptance Criteria" queries from `references/wiql-patterns.md` against the broader backlog under `$cfg.iterationRoot`.

Report counts only (not full lists) unless the user asks to drill in. Note `UNDER '<iterationRoot>'` includes every child sprint (the current one too) — to exclude the active sprint, add `AND [System.IterationPath] <> @CurrentIteration('[<PROJECT>]\<TEAM>')` to each query:
```
 Backlog health (team backlog under <iterationRoot>; includes all sprints):
   Unpointed PBIs        N
   Missing AC            N
```

## Step 5: Offer next actions

- `"Show my work"` → `/my-sprint-work`
- `"Groom unpointed items"` → list them and offer `/prepare-pbi` on each
- `"Flag items for next sprint"` → update Iteration Path on selected items
