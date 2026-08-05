---
description: Review the approved backlog, identify sprint candidates, and suggest a prioritised shortlist based on story points, tags, and capacity.
---

# Prioritize Backlog

Load this skill's `SKILL.md` (azure-boards-organiser) and resolve config (see SKILL.md → Configuration).

If an Azure DevOps MCP server is connected this session, use its tools for all reads/writes; otherwise use the PowerShell `az` blocks below (see SKILL.md → Execution backend).

```powershell
$cfg = Get-Content "$HOME/.claude/skills/azure-boards-organiser/config.json" -Raw | ConvertFrom-Json
```
If `config.json` is missing, stop and tell the user to copy `config.example.json`.

## Usage
```
/prioritize-backlog [--capacity <points>] [--tag <tag>]
```
- `--capacity <N>`: target sprint capacity in story points (default: ask user)
- `--tag <tag>`: filter backlog to items with this tag

---

## Step 1: Get capacity

If `--capacity` not provided, ask:
> "What is the team's target story point capacity for the next sprint?"

## Step 2: Fetch approved backlog

Run the "Top-priority approved PBIs (sprint candidates)" WIQL from `references/wiql-patterns.md`:
```powershell
$wiql = @'
SELECT [System.Id], [System.Title], [System.State],
       [Microsoft.VSTS.Scheduling.StoryPoints],
       [Microsoft.VSTS.Common.Priority],
       [System.Tags], [System.AreaPath]
FROM WorkItems
WHERE [System.WorkItemType] = 'Product Backlog Item'
  AND [System.State] = 'Approved'
  AND [System.IterationPath] UNDER '<iterationRoot>'
ORDER BY [Microsoft.VSTS.Common.BacklogPriority]
'@ -replace '<iterationRoot>', $cfg.iterationRoot
$candidates = az boards query --wiql $wiql --project $cfg.project -o json | ConvertFrom-Json
```
Apply the tag filter client-side if `--tag` was provided (or add `AND [System.Tags] CONTAINS '<tag>'` to the WIQL before the close).

Also run the "Unpointed PBIs in backlog" WIQL and note those separately — they cannot be reliably scheduled.

## Step 3: Analyse and recommend

Walk down the stack-ranked backlog and greedily fill capacity:

```
Recommended sprint load (<capacity> pts target):

  INCLUDE
  ───────
  [ID]  Title                              Pts  Tags
  1234  Configure hub VNet peering...       5   networking, bicep
  1237  DINE policy for diagnostic sets     3   azure-policy, monitoring
  1241  Automate RBAC group creation        5   iam, pipeline
                                           ──
                                           13 / <capacity> pts

  BORDERLINE (would exceed capacity)
  ──────────────────────────────────
  [ID]  Title                              Pts  Tags
  1245  Implement cost tag inheritance      8   cost-management, pipeline
  (would bring total to 21 pts)

  SKIPPED (unpointed — needs grooming first)
  ──────────────────────────────────────────
  [ID]  Title
  1250  Review Log Analytics retention...
  1253  Azure Policy exemption workflow...
```

Note any items with Points > 8 and flag them as candidates for splitting.

## Step 4: Confirm sprint assignment

Ask: **"Assign the INCLUDE list to sprint <SprintName>? (yes / no / adjust)"**

If confirmed, update Iteration Path for each selected item. Pass `--fields` as an array of `Name=Value` strings — never comma-joined. Never set `BacklogPriority` manually (this command assigns the iteration only; it does not reorder the stack rank):
```powershell
$fields = @("System.IterationPath=$($cfg.iterationRoot)\$SprintName")
$azArgs = @('boards','work-item','update','--id', $Id, '--fields') + $fields
az @azArgs -o json | ConvertFrom-Json | Out-Null
```

## Step 5: Handle unpointed items

For each unpointed item in the backlog, offer:
- `"Run /prepare-pbi <ID>"` to enrich and point it
- `"Skip for now"` — leave it in backlog
- `"Remove from backlog"` — update State to Removed (confirm first)

## Step 6: Output summary

```
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
 BACKLOG PRIORITIZATION COMPLETE
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
 Assigned to <SprintName>:  N items / X pts
 Remaining approved backlog: N items / X pts
 Unpointed (needs grooming): N items
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
```
