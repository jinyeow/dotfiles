---
description: Backlog/sprint hygiene report — stale, approved-but-unpointed, owner-less, and orphaned items, with remediation offers.
---

# Find Stale

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

Accepts an optional staleness window: `/find-stale [--days <N>]` (default `N = 14`).

## Step 1: Stale items — untouched for N days

Run the "Stale items — untouched for N days" pattern from `references/wiql-patterns.md`, substituting `@Today - <N>` for the staleness window (default 14).

```powershell
$days = 14   # override from --days
$wiql = @'
SELECT [System.Id], [System.Title], [System.WorkItemType], [System.State],
       [System.AssignedTo], [System.ChangedDate]
FROM WorkItems
WHERE [System.WorkItemType] IN ('Product Backlog Item', 'Bug', 'Task')
  AND [System.State] NOT IN ('Done', 'Removed')
  AND [System.ChangedDate] < @Today - 14
  AND [System.IterationPath] UNDER 'ITERATION_ROOT'
ORDER BY [System.ChangedDate]
'@ -replace '\s*\r?\n\s*', ' '
$wiql = $wiql.Replace('@Today - 14', "@Today - $days").Replace('ITERATION_ROOT', $cfg.iterationRoot)
$stale = az boards query --wiql $wiql --project $cfg.project --organization $org -o json | ConvertFrom-Json
```

## Step 2: Approved-but-unpointed

Run the "Unpointed PBIs in backlog" pattern narrowed to `State = 'Approved'` (see the "Approved-but-unpointed" note in `references/wiql-patterns.md`). If the numeric-empty predicate (`StoryPoints = ''`) misbehaves on this org, drop it and filter client-side after `ConvertFrom-Json` (`$_.fields.'Microsoft.VSTS.Scheduling.StoryPoints'` null-or-zero).

## Step 3: Active items with no owner

Run the "Active items with no owner" pattern (Committed in the current sprint with empty `AssignedTo`).

```powershell
$wiql = @'
SELECT [System.Id], [System.Title], [System.WorkItemType], [System.State]
FROM WorkItems
WHERE [System.State] = 'Committed'
  AND [System.AssignedTo] = ''
  AND [System.IterationPath] = @CurrentIteration('[<PROJECT>]\<TEAM>')
'@ -replace '<PROJECT>', $cfg.project -replace '<TEAM>', $cfg.team -replace '\s*\r?\n\s*', ' '
$noOwner = az boards query --wiql $wiql --project $cfg.project --organization $org -o json | ConvertFrom-Json
```

## Step 4: Orphan checks (parent/child)

**WIQL has no subqueries** — you cannot express done-parent-with-open-children or open-children-under-done-parent in one flat query. Reconcile in two steps:

1. Query candidate parents (PBIs/Features) under `$cfg.iterationRoot` plus the relevant child set, then match on `System.Parent` client-side after `ConvertFrom-Json`; **or**
2. For each candidate parent, run the flat "Children of a PBI — flat single-parent" query (`[System.Parent] = <ID>`) from `references/wiql-patterns.md` and inspect the child states. (The `WorkItemLinks` variant needs MCP/REST — `az boards query` is flat-only.)

Flag two cases:
- **Done parent, open children** — parent `Done` but a child is not `Done`/`Removed`.
- **Open children, done-able parent** — all children `Done` but the parent is still open.

## Step 5: Output

Lead with grouped counts, then one list per category. Cap long lists (e.g. first 20 per category) and state the truncation explicitly — never silently drop rows.

```
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
 BACKLOG HYGIENE  (stale window: N days)
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
 Stale items            N
 Approved-but-unpointed N
 No owner (Committed)   N
 Orphans                N
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
```

Then per category (ID — Title — Type/State — Owner — days since change):
```
 Stale (showing 20 of N):
   1234  Configure hub VNet peering …   PBI/Committed   unassigned   31d
   …
```

## Step 6: Offer next actions

- **Unpointed / missing AC** → `/prepare-pbi <ID>` to enrich and size.
- **No owner** → assign an owner (confirm-first `az boards work-item update --id <ID> --fields System.AssignedTo=<upn> --organization $org`).
- **Orphans** → `/move-to-done <ID>` for the parent, or close/transition the open children.
- **Truly dead items** → Remove (confirm-first; `System.State=Removed`).
