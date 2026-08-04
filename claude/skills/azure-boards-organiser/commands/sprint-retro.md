---
description: End-of-sprint retro — committed vs done points, carry-over and spillover analysis, and a data-seeded retro notes scaffold.
---

# Sprint Retro

Load this skill's `SKILL.md` (azure-boards-organiser) and resolve config (see SKILL.md → Configuration).

```powershell
$cfg = Get-Content "$HOME/.claude/skills/azure-boards-organiser/config.json" -Raw | ConvertFrom-Json
# org comes from: az devops configure --list
```
If `config.json` is missing, stop and tell the user to copy `config.example.json` first.

If an Azure DevOps MCP server is connected this session, use its tools for all reads/writes; otherwise use the PowerShell `az` blocks below.

Accepts an optional sprint name: `/sprint-retro <SprintName>`. Resolve it (else the current sprint), then build the target iteration path:
```powershell
# $SprintName: the /sprint-retro argument if given; otherwise the current sprint:
if (-not $SprintName) {
  $SprintName = az boards iteration team list --team $cfg.team --project $cfg.project --timeframe current --query '[0].name' -o tsv
}
$target = "$($cfg.iterationRoot)\$SprintName"
```

## Step 1: Fetch sprint items

Run the **"Sprint velocity summary"** pattern from `references/wiql-patterns.md` against the target sprint to get PBIs/Bugs with State + StoryPoints. Add `[System.CreatedDate]` to the SELECT so spillover (newly created in-sprint) is derivable.

```powershell
$wiql = @'
SELECT [System.Id], [System.Title], [System.State],
       [Microsoft.VSTS.Scheduling.StoryPoints], [System.CreatedDate]
FROM WorkItems
WHERE [System.WorkItemType] IN ('Product Backlog Item', 'Bug')
  AND [System.IterationPath] = '<TARGET>'
  AND [System.State] <> 'Removed'
'@ -replace '<TARGET>', $target
$items = az boards query --wiql $wiql --project $cfg.project -o json | ConvertFrom-Json
```

## Step 2: Compute committed vs done + carry-over

- **Committed points**: sum StoryPoints across all PBIs/Bugs in the sprint.
- **Done points**: sum StoryPoints where State = 'Done'.
- **Completion %**: done ÷ committed × 100.
- **Carry-over**: items not Done at sprint end (State ∈ New/Approved/Committed). These need a home — next sprint or back to the backlog (Step 4).

## Step 3: Spillover analysis

For each carry-over item, derive *why* it slipped where cheap:
- **Newly created in-sprint** (approximate): `CreatedDate` later than the sprint start date (resolve the iteration's `startDate` from `az boards iteration team list --team $cfg.team`, compare client-side after `ConvertFrom-Json`). ⚠️ This only catches items *created* after the start — items created earlier but *moved into* this sprint mid-sprint are invisible without iteration-change history (MCP/revisions API). Label it "newly created in-sprint", not "added mid-sprint".
- **Oversized**: StoryPoints > 8 (per the "Oversized PBIs" pattern threshold) — likely needed splitting.
- Otherwise: note as "no cheap signal" — don't speculate.

## Step 4: Retro notes scaffold

Pre-seed the three columns with the data-driven observations from Steps 2–3, then leave room for the team:

```
Went well
  - <Done count> items / <Done pts> pts completed (<completion>%)
  - ...

Didn't go well
  - <N> items carried over (<carry-over pts> pts)
  - <N> items newly created in-sprint
  - <N> oversized items (> 8 pts)
  - ...

Action items
  - [ ] ...
```

## Step 5: Output

```
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
 SPRINT RETRO  <SprintName>
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
 Committed       XX pts across N items
 Done            XX pts (XX%)
 Carry-over      N items (XX pts)

 Spillover:
   Newly created in-sprint  N items
   Oversized (>8 pts)  N items
   No cheap signal     N items
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
```
Then print the retro notes scaffold from Step 4.

## Step 6: Offer next actions

These are read/report by default — **any write is confirm-first**.

- `"Move carry-over to next sprint"` → confirm, then update each carry-over item's `System.IterationPath` to the next sprint:
  ```powershell
  $fields = @("System.IterationPath=$($cfg.iterationRoot)\$nextSprint")
  $azArgs = @('boards','work-item','update','--id', $Id, '--fields') + $fields
  az @azArgs -o json | ConvertFrom-Json | Out-Null
  ```
- `"Send carry-over to backlog"` → confirm, then set `System.IterationPath` to `$cfg.iterationRoot` (the groomable backlog root that `/prioritize-backlog` and `/find-stale` scope `UNDER`), **not** the bare project root.
- `"Show my work next sprint"` → `/my-sprint-work`
