---
description: Add hours to a Task's CompletedWork (cumulative total) and adjust RemainingWork, with a before→after confirm.
---

# Log Time

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

**`CompletedWork` is a CUMULATIVE TOTAL, not an append log.** To log hours you read the current value, add the new hours, and write the *sum* — never overwrite with the delta. This is the central correctness rule of this command.

Usage: `/log-time <TASK_ID> [hours] [--remaining <h>]`. If `hours` is omitted, ask for it.

## Step 1: Validate input

- If `hours` is missing, ask the user how many hours to log.
- If `hours` is negative or zero, stop with: "Hours to log must be a positive number — got `<value>`. Nothing was written."
- If `--remaining <h>` is supplied and negative, stop with: "RemainingWork cannot be negative — got `<value>`. Nothing was written."

## Step 2: Read the Task

```powershell
$wi = az boards work-item show --id $TaskId --organization $org -o json | ConvertFrom-Json
$type = $wi.fields.'System.WorkItemType'
$currentCompleted = [double]($wi.fields.'Microsoft.VSTS.Scheduling.CompletedWork' ?? 0)
$currentRemaining = [double]($wi.fields.'Microsoft.VSTS.Scheduling.RemainingWork' ?? 0)
```

If `$type -ne 'Task'`, stop with: "Item <ID> is a `<type>`, not a Task. Time tracking (CompletedWork/RemainingWork) is logged on Tasks. Nothing was written."

## Step 3: Compute new values

- `newCompleted = currentCompleted + hours`  ← the cumulative sum, never the delta.
- If the user passed `--remaining <h>`, `newRemaining = <h>` (honour it verbatim).
- Otherwise `newRemaining = [Math]::Max(0, currentRemaining - hours)`.

## Step 4: Show before→after and confirm

Present a table and wait for explicit confirmation before writing:

| Field | Before | After |
|-------|--------|-------|
| CompletedWork (h) | `<currentCompleted>` | `<newCompleted>` |
| RemainingWork (h) | `<currentRemaining>` | `<newRemaining>` |

State plainly: "Logging `<hours>`h to Task <ID> — `<Title>`." Do not proceed until the user confirms.

## Step 5: Write both fields in one update

```powershell
$fields = @(
  "Microsoft.VSTS.Scheduling.CompletedWork=$newCompleted"
  "Microsoft.VSTS.Scheduling.RemainingWork=$newRemaining"
)
$azArgs = @('boards','work-item','update','--id', $TaskId, '--fields') + $fields + @('--organization', $org)
az @azArgs -o json | ConvertFrom-Json | Out-Null
```

Re-read the Task and confirm CompletedWork now equals `newCompleted`.

## Step 6: Offer next actions

- `"Log time on another task"` → re-run `/log-time <TASK_ID>`
- `"See my time this sprint"` → run the "My time spent this sprint" WIQL from `references/wiql-patterns.md`
- `"Move the parent PBI to Done"` → suggest `/move-to-done <ID>`
