---
description: Validate the transition for a PBI/Bug/Task and move it to Done — checking child Tasks and Acceptance Criteria first.
---

# Move to Done

Load this skill's `SKILL.md` (azure-boards-organiser) and resolve config (see SKILL.md → Configuration).

```powershell
$cfg = Get-Content "$HOME/.claude/skills/azure-boards-organiser/config.json" -Raw | ConvertFrom-Json
$org = $cfg.org
if (-not $org) { throw "config.json has no 'org'. Copy config.example.json and set it to your organisation URL." }
```
`--organization $org` goes on every call and is **not** optional: this machine has no `az devops` default
organisation, so omitting it fails with `--organization must be specified`. `--org` is not accepted by
`az boards query` either — it fails the same misleading way. If `config.json` is missing, stop and tell the
user to copy `config.example.json` to `config.json` and fill it in.

If an Azure DevOps MCP server is connected this session, use its tools for all reads/writes; otherwise use the PowerShell `az` blocks below.

**Validate the transition; do not blind-set `State=Done`.** Read the item's type and current state first, check completion preconditions, and step through intermediate states if a direct jump is rejected.

> **Process-customization caveat** (SKILL.md): states, reasons, and allowed transitions can be renamed or restricted per process. Treat the Scrum path below as the default; if a write is rejected, read the item's actual states/transitions and adapt rather than assuming.

Usage: `/move-to-done <ID>`.

## Step 1: Read the item

```powershell
$wi = az boards work-item show --id $Id --organization $org -o json | ConvertFrom-Json
$type  = $wi.fields.'System.WorkItemType'
$state = $wi.fields.'System.State'
```

If already `Done`, report and stop.

## Step 2: Preconditions for a PBI or Bug

If `$type` is `Product Backlog Item` or `Bug`:

1. **Open child Tasks.** Query the item's child Tasks directly with a flat single-parent query — filtered to `Task` so child PBIs/Bugs are never mistaken for Tasks (and never auto-closed). The closing `"@` must be at column 0 (PowerShell rejects whitespace before a here-string terminator), so keep this block un-indented:

```powershell
$childWiql = @"
SELECT [System.Id], [System.Title], [System.State]
FROM WorkItems
WHERE [System.Parent] = $Id
  AND [System.WorkItemType] = 'Task'
  AND [System.State] <> 'Removed'
"@ -replace '\s*\r?\n\s*', ' '   # double-quoted so $Id interpolates
$openTasks = az boards query --wiql $childWiql --project $cfg.project --organization $org -o json |
  ConvertFrom-Json | Where-Object { $_.fields.'System.State' -ne 'Done' }
```

   If `$openTasks` is non-empty, list them (ID, Title, State) and ask: proceed anyway / auto-close them to Done / abort.
2. **Acceptance Criteria.** If `Microsoft.VSTS.Common.AcceptanceCriteria` is empty, warn that AC is empty — ask whether to proceed.

(`[System.Parent] = <ID>` with a literal ID is a field match, not a subquery — WIQL has no subqueries.)

## Step 3: Plan the transition

Scrum PBI/Bug path is **New → Approved → Committed → Done**.

- ADO usually allows a direct `New → Done`, but some customized processes don't.
- If a direct State update is rejected, step through the intermediate states in order (e.g. set `Approved`, then `Committed`, then `Done`), reading the item between writes to confirm each move took.
- Tasks transition `To Do → In Progress → Done`.

## Step 4: Confirm, then update State

State the move: "Moving <type> <ID> — `<Title>` from `<state>` → Done." Wait for confirmation.

```powershell
$fields = @('System.State=Done')
$azArgs = @('boards','work-item','update','--id', $Id, '--fields') + $fields + @('--organization', $org)
az @azArgs -o json | ConvertFrom-Json | Out-Null
```

Only set `System.Reason` if the default reason for the Done transition is wrong, or if ADO rejects the update without one. If a direct jump fails, retry stepping through intermediate states (Step 3).

If the user chose to auto-close child Tasks (Step 2), update each to `State=Done` the same way before closing the parent.

## Step 5: Report final state

Re-read the item and report the final `System.State` (and any children closed).

## Step 6: Offer next actions

- `"Move another item to Done"` → re-run `/move-to-done <ID>`
- `"Log remaining time first"` → suggest `/log-time <TASK_ID>`
- `"Show sprint summary"` → suggest `/sprint-summary`
