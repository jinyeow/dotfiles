---
description: Standup view — done since yesterday, in progress with remaining work, and blockers / at-risk. Pure read, standup-ready bullets.
---

# Daily Standup

Load this skill's `SKILL.md` (azure-boards-organiser) and resolve config (see SKILL.md → Configuration).

```powershell
$cfg = Get-Content "$HOME/.claude/skills/azure-boards-organiser/config.json" -Raw | ConvertFrom-Json
# org comes from: az devops configure --list
```
If `config.json` is missing, stop and tell the user to copy `config.example.json` first.

If an Azure DevOps MCP server is connected this session, use its tools for all reads/writes; otherwise use the PowerShell `az` blocks below.

`/daily-standup` — pure read. Scoped to `@Me` in the current sprint.

## Step 1: Done since yesterday

Run the **"Items changed since yesterday (standup)"** pattern from `references/wiql-patterns.md`. Flag items now in State = 'Done', and items with CompletedWork > 0. (A true day-over-day CompletedWork *delta* needs the revision-history API — not available from flat WIQL fields; use the MCP server if you need actual hours-logged-today.)

```powershell
$wiql = @'
SELECT [System.Id], [System.Title], [System.WorkItemType], [System.State],
       [System.AssignedTo], [System.ChangedDate],
       [Microsoft.VSTS.Scheduling.CompletedWork],
       [Microsoft.VSTS.Scheduling.RemainingWork]
FROM WorkItems
WHERE [System.AssignedTo] = @Me
  AND [System.IterationPath] = @CurrentIteration('[<PROJECT>]\<TEAM>')
  AND [System.ChangedDate] >= @Today - 1
  AND [System.State] <> 'Removed'
ORDER BY [System.ChangedDate] DESC
'@ -replace '<PROJECT>', $cfg.project -replace '<TEAM>', $cfg.team
$changed = az boards query --wiql $wiql --project $cfg.project -o json | ConvertFrom-Json
```

## Step 2: In progress

My active PBIs and Tasks in the current sprint. PBIs: the **"My incomplete PBIs in current sprint"** pattern. Tasks assigned to me that are not yet done (covers To Do *and* In Progress — the "My time spent this sprint" pattern filters `CompletedWork > 0` and would miss un-logged work):
```powershell
$taskWiql = @'
SELECT [System.Id], [System.Title], [System.State], [System.Parent],
       [Microsoft.VSTS.Scheduling.RemainingWork]
FROM WorkItems
WHERE [System.WorkItemType] = 'Task'
  AND [System.AssignedTo] = @Me
  AND [System.IterationPath] = @CurrentIteration('[<PROJECT>]\<TEAM>')
  AND [System.State] NOT IN ('Done', 'Removed')
ORDER BY [System.State]
'@ -replace '<PROJECT>', $cfg.project -replace '<TEAM>', $cfg.team
$inProgress = az boards query --wiql $taskWiql --project $cfg.project -o json | ConvertFrom-Json
```

## Step 3: Blockers / at-risk

Reuse the **"Tagged blocked, active sprint"** and **"At-risk — committed but stalled (no change in N days)"** patterns from `references/wiql-patterns.md`. Filter at-risk to `@Me` client-side for a personal standup.

## Step 4: Output

Concise, standup-ready bullets a person can read aloud:

```
Yesterday / done:
  - #1234 Configure hub VNet peering — moved to Done
  - #1240 Author Bicep module — 6h CompletedWork

In progress:
  - #1255 Wire spoke egress through firewall — 4h remaining
  - #1260 ...

Blockers / at-risk:
  - #1248 Awaiting network team sign-off (tagged blocked)
  - #1251 Committed, no change in 4 days ⚠️
```

If a section is empty, say so ("Nothing done since yesterday", "No blockers").

## Step 5: Offer next actions

- `"Log time"` → `/log-time <TASK_ID>`
- `"Mark done"` → `/move-to-done <ID>`
- `"Review blockers"` → `/blocked-work`
