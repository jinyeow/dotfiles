# WIQL Patterns Reference

Common WIQL query templates for the Scrum process used by this skill.
Resolve `<PROJECT>`, `<TEAM>`, and `<iterationRoot>` from `config.json` + `az devops` defaults before executing (see `SKILL.md` → Configuration).

> **WIQL is not SQL.** It supports only two `FROM` sources — `WorkItems` (flat) and `WorkItemLinks` (one hop of links). There are **no subqueries**: `WHERE [System.Parent] IN (SELECT …)` is invalid. **`az boards query` runs flat (`WorkItems`) queries only** — its help states *"Only supports flat queries"* — so `WorkItemLinks` queries need the MCP server or the REST `wiql` endpoint, not the CLI. For children via the CLI, use the **flat single-parent / two-step** approach: run the parent query, collect the IDs, then `WHERE [System.Parent] IN (1234, 1240, 1255)` (or `= <ID>` for one parent) with literal IDs.

---

## Sprint Queries

### All PBIs in current sprint (team-scoped)
```sql
SELECT [System.Id], [System.Title], [System.State], [System.AssignedTo],
       [Microsoft.VSTS.Scheduling.StoryPoints], [Microsoft.VSTS.Common.Priority],
       [System.Tags]
FROM WorkItems
WHERE [System.WorkItemType] = 'Product Backlog Item'
  AND [System.IterationPath] = @CurrentIteration('[<PROJECT>]\<TEAM>')
  AND [System.State] <> 'Removed'
ORDER BY [Microsoft.VSTS.Common.BacklogPriority]
```

### My incomplete PBIs in current sprint
PBIs don't carry `CompletedWork` in Scrum (time is tracked on child Tasks) — roll that up from Tasks by `System.Parent` if you need per-PBI time.
```sql
SELECT [System.Id], [System.Title], [System.State],
       [Microsoft.VSTS.Scheduling.StoryPoints]
FROM WorkItems
WHERE [System.WorkItemType] = 'Product Backlog Item'
  AND [System.AssignedTo] = @Me
  AND [System.IterationPath] = @CurrentIteration('[<PROJECT>]\<TEAM>')
  AND [System.State] NOT IN ('Done', 'Removed')
ORDER BY [Microsoft.VSTS.Common.BacklogPriority]
```

### Tasks under my PBIs in current sprint (WorkItemLinks — MCP/REST only)
> ⚠️ `az boards query` is flat-only and **cannot run this** — use it via the MCP server or the REST `wiql` endpoint. For the CLI, prefer the flat two-step below. This returns link rows; source = parent PBI, target = each child Task.
```sql
SELECT [System.Id], [System.Title], [System.State], [System.AssignedTo],
       [Microsoft.VSTS.Scheduling.RemainingWork],
       [Microsoft.VSTS.Scheduling.CompletedWork]
FROM WorkItemLinks
WHERE [Source].[System.WorkItemType] = 'Product Backlog Item'
  AND [Source].[System.AssignedTo] = @Me
  AND [Source].[System.IterationPath] = @CurrentIteration('[<PROJECT>]\<TEAM>')
  AND [System.Links.LinkType] = 'System.LinkTypes.Hierarchy-Forward'
  AND [Target].[System.WorkItemType] = 'Task'
  AND [Target].[System.State] <> 'Removed'
MODE (MustContain)
```
> **CLI approach (flat two-step)**: query my PBI IDs first, then
> `... FROM WorkItems WHERE [System.WorkItemType] = 'Task' AND [System.Parent] IN (1234, 1240) AND [System.IterationPath] = @CurrentIteration('[<PROJECT>]\<TEAM>')`. Via MCP/REST you can run the link query above directly and read each relation's `target`.

### Sprint velocity summary (points by state)
```sql
SELECT [System.Id], [System.State], [Microsoft.VSTS.Scheduling.StoryPoints]
FROM WorkItems
WHERE [System.WorkItemType] IN ('Product Backlog Item', 'Bug')
  AND [System.IterationPath] = '<iterationRoot>\<SprintName>'
  AND [System.State] <> 'Removed'
```
*Aggregate in code: sum StoryPoints grouped by State.*

### Items changed since yesterday (standup)
```sql
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
```

---

## Backlog Queries

### Unpointed PBIs in backlog (needs grooming)
```sql
SELECT [System.Id], [System.Title], [System.State],
       [Microsoft.VSTS.Scheduling.StoryPoints],
       [Microsoft.VSTS.Common.Priority]
FROM WorkItems
WHERE [System.WorkItemType] = 'Product Backlog Item'
  AND [System.State] IN ('New', 'Approved')
  AND (
    [Microsoft.VSTS.Scheduling.StoryPoints] = ''
    OR [Microsoft.VSTS.Scheduling.StoryPoints] = 0
  )
  AND [System.IterationPath] UNDER '<iterationRoot>'
ORDER BY [Microsoft.VSTS.Common.BacklogPriority]
```
> Numeric-empty matching is inconsistent across ADO versions. If `= ''` misbehaves for StoryPoints, drop that predicate and filter client-side (`$_.fields.'Microsoft.VSTS.Scheduling.StoryPoints'` null-or-zero) after `ConvertFrom-Json`.

### PBIs missing Acceptance Criteria
```sql
SELECT [System.Id], [System.Title], [System.State]
FROM WorkItems
WHERE [System.WorkItemType] = 'Product Backlog Item'
  AND [System.State] IN ('New', 'Approved', 'Committed')
  AND [Microsoft.VSTS.Common.AcceptanceCriteria] = ''
  AND [System.IterationPath] UNDER '<iterationRoot>'
ORDER BY [Microsoft.VSTS.Common.BacklogPriority]
```

### Top-priority approved PBIs (sprint candidates)
```sql
SELECT [System.Id], [System.Title], [System.State],
       [Microsoft.VSTS.Scheduling.StoryPoints],
       [Microsoft.VSTS.Common.Priority],
       [System.Tags], [System.AreaPath]
FROM WorkItems
WHERE [System.WorkItemType] = 'Product Backlog Item'
  AND [System.State] = 'Approved'
  AND [System.IterationPath] UNDER '<iterationRoot>'
ORDER BY [Microsoft.VSTS.Common.BacklogPriority]
```

### PBIs by tag (filter to a domain area)
```sql
SELECT [System.Id], [System.Title], [System.State],
       [Microsoft.VSTS.Scheduling.StoryPoints]
FROM WorkItems
WHERE [System.WorkItemType] = 'Product Backlog Item'
  AND [System.Tags] CONTAINS '<tag>'
  AND [System.IterationPath] UNDER '<iterationRoot>'
  AND [System.State] <> 'Removed'
ORDER BY [Microsoft.VSTS.Common.BacklogPriority]
```

### Oversized PBIs (split candidates)
```sql
SELECT [System.Id], [System.Title], [System.State],
       [Microsoft.VSTS.Scheduling.StoryPoints]
FROM WorkItems
WHERE [System.WorkItemType] = 'Product Backlog Item'
  AND [Microsoft.VSTS.Scheduling.StoryPoints] > 8
  AND [System.State] NOT IN ('Done', 'Removed')
  AND [System.IterationPath] UNDER '<iterationRoot>'
ORDER BY [Microsoft.VSTS.Scheduling.StoryPoints] DESC
```

---

## Hygiene Queries (find-stale)

### Stale items — untouched for N days
```sql
SELECT [System.Id], [System.Title], [System.WorkItemType], [System.State],
       [System.AssignedTo], [System.ChangedDate]
FROM WorkItems
WHERE [System.WorkItemType] IN ('Product Backlog Item', 'Bug', 'Task')
  AND [System.State] NOT IN ('Done', 'Removed')
  AND [System.ChangedDate] < @Today - 14
  AND [System.IterationPath] UNDER '<iterationRoot>'
ORDER BY [System.ChangedDate]
```

### Approved-but-unpointed (cannot be scheduled)
Use "Unpointed PBIs in backlog" above, narrowed to `State = 'Approved'`.

### Active items with no owner
```sql
SELECT [System.Id], [System.Title], [System.WorkItemType], [System.State]
FROM WorkItems
WHERE [System.State] = 'Committed'
  AND [System.AssignedTo] = ''
  AND [System.IterationPath] = @CurrentIteration('[<PROJECT>]\<TEAM>')
```

> **Orphan checks needing parent/child** (done-parent-with-open-children, open-children-under-done-parent) cannot be expressed in one flat query — there are no subqueries. Run the flat **Children of a PBI — flat single-parent** query (`[System.Parent] = <ID>`) per candidate parent, or fetch parents + their children and reconcile client-side.

---

## Blocked / At-risk Queries (blocked-work)

Blocked-ness has no native Scrum field; teams encode it by **tag** (e.g. `blocked`) or a comment convention. Combine signals:

### Tagged blocked, active sprint
```sql
SELECT [System.Id], [System.Title], [System.WorkItemType], [System.State],
       [System.AssignedTo], [System.Tags], [System.ChangedDate]
FROM WorkItems
WHERE [System.Tags] CONTAINS 'blocked'
  AND [System.State] NOT IN ('Done', 'Removed')
  AND [System.IterationPath] = @CurrentIteration('[<PROJECT>]\<TEAM>')
ORDER BY [System.ChangedDate]
```

### At-risk — committed but stalled (no change in N days)
```sql
SELECT [System.Id], [System.Title], [System.State], [System.AssignedTo],
       [System.ChangedDate], [Microsoft.VSTS.Scheduling.RemainingWork]
FROM WorkItems
WHERE [System.State] = 'Committed'
  AND [System.ChangedDate] < @Today - 3
  AND [System.IterationPath] = @CurrentIteration('[<PROJECT>]\<TEAM>')
ORDER BY [System.ChangedDate]
```

---

## Bug Queries

### Active bugs in current sprint
```sql
SELECT [System.Id], [System.Title], [System.State], [System.AssignedTo],
       [Microsoft.VSTS.Common.Priority],
       [Microsoft.VSTS.Scheduling.StoryPoints]
FROM WorkItems
WHERE [System.WorkItemType] = 'Bug'
  AND [System.IterationPath] = @CurrentIteration('[<PROJECT>]\<TEAM>')
  AND [System.State] NOT IN ('Done', 'Removed')
ORDER BY [Microsoft.VSTS.Common.Priority], [Microsoft.VSTS.Common.BacklogPriority]
```
> Bugs may be configured "as requirements" (on the backlog, with Story Points) or "as tasks" (under PBIs) depending on team settings. Query and report them separately from PBIs and don't assume they carry Story Points.

### Bugs not assigned to any sprint (backlog debt)
> Scopes to the bare project root — i.e. bugs sitting *outside* the team backlog root (`$cfg.iterationRoot`). Intentionally narrower than "all unscheduled bugs": groomable backlog bugs live under the iteration root like PBIs.
```sql
SELECT [System.Id], [System.Title], [System.State],
       [Microsoft.VSTS.Common.Priority], [System.CreatedDate]
FROM WorkItems
WHERE [System.WorkItemType] = 'Bug'
  AND [System.State] NOT IN ('Done', 'Removed')
  AND [System.IterationPath] = '<PROJECT>'
ORDER BY [Microsoft.VSTS.Common.Priority], [System.CreatedDate]
```

---

## Work Item Links (Parent/Child)

### Children of a PBI — flat single-parent (preferred for one known parent)
`[System.Parent] = <ID>` is a field match (a single literal ID), **not** a subquery — it is valid WIQL and returns child fields directly, so no target-resolution step is needed. Prefer this whenever the parent ID is known. Filter `[System.WorkItemType]` to avoid mixing child PBIs/Bugs with Tasks.
```sql
SELECT [System.Id], [System.Title], [System.State],
       [Microsoft.VSTS.Scheduling.RemainingWork],
       [Microsoft.VSTS.Scheduling.CompletedWork]
FROM WorkItems
WHERE [System.Parent] = <PBI_ID>
  AND [System.WorkItemType] = 'Task'
  AND [System.State] <> 'Removed'
```
For several known parents, use literal IDs: `[System.Parent] IN (1234, 1240, 1255)`. In PowerShell, build these with a **double-quoted** here-string so the ID(s) interpolate.

### Children of a PBI — WorkItemLinks (hierarchy, MCP/REST only)
> ⚠️ Not runnable via `az boards query` (flat-only) — use the MCP server or REST `wiql` endpoint. For the CLI, use the flat single-parent query above. Use this when you need the link relations themselves; returns relation rows (source/target refs), not flat fields.
```sql
SELECT [System.Id], [System.Title], [System.WorkItemType], [System.State],
       [Microsoft.VSTS.Scheduling.RemainingWork],
       [Microsoft.VSTS.Scheduling.CompletedWork]
FROM WorkItemLinks
WHERE [Source].[System.Id] = <PBI_ID>
  AND [System.Links.LinkType] = 'System.LinkTypes.Hierarchy-Forward'
  AND [Target].[System.State] <> 'Removed'
MODE (MustContain)
```

---

## Time Tracking Queries

### My time spent this sprint (CompletedWork on Tasks)
```sql
SELECT [System.Id], [System.Title], [System.Parent],
       [Microsoft.VSTS.Scheduling.CompletedWork],
       [Microsoft.VSTS.Scheduling.RemainingWork]
FROM WorkItems
WHERE [System.WorkItemType] = 'Task'
  AND [System.AssignedTo] = @Me
  AND [System.IterationPath] = @CurrentIteration('[<PROJECT>]\<TEAM>')
  AND [Microsoft.VSTS.Scheduling.CompletedWork] > 0
ORDER BY [System.Parent]
```

---

## Field Value Reference

### PBI States (Scrum)
| State | Meaning |
|-------|---------|
| New | Captured, not yet refined |
| Approved | Refined, ready for sprint |
| Committed | In active sprint |
| Done | Completed |
| Removed | Cancelled / won't do |

> States can be customized per process. Before transitioning (`/move-to-done`), read the item's current state and the type's allowed transitions rather than assuming this table.

### Task States (Scrum)
| State | Meaning |
|-------|---------|
| To Do | Not started |
| In Progress | Being worked |
| Done | Completed |
| Removed | Cancelled |

### Priority Values
| Value | Label |
|-------|-------|
| 1 | Critical |
| 2 | High |
| 3 | Medium |
| 4 | Low |

### Common Tags
Pull the live taxonomy from `config.json` → `tags`. Defaults: `azure-policy`, `bicep`, `networking`, `iam`, `landing-zone`, `monitoring`, `cost-management`, `security`, `pipeline`, `documentation`, `tech-debt`.

---

## Notes

- `@Me` resolves to the currently authenticated user's UPN.
- `@CurrentIteration('[Project]\Team')` requires exact project/team name matching — check with `az boards iteration team list`.
- WIQL has no `LIMIT`, and `az boards query` has **no `--top`**. Cap client-side after `ConvertFrom-Json` (`| Select-Object -First <N>`) or with a `--query` JMESPath slice.
- Date literals: `'2026-06-01'` (ISO). Relative: `@Today`, `@Today - 7`.
- `az boards query --wiql` accepts the query string; in PowerShell pass it via a single-quoted here-string (`@' … '@`) so `$`, `@`, and `\` stay literal.
