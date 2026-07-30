---
name: azure-boards-organiser
description: >-
  Manage Azure DevOps Boards work items for a Scrum process — read and write PBIs, Bugs,
  and Tasks; run sprint and backlog WIQL queries; enrich, decompose, prioritise, and report.
  Use for any Azure Boards / Azure DevOps work-item task: viewing or updating a PBI/Bug/Task,
  sprint planning, sprint summary or retro, daily standup, backlog grooming, logging time,
  moving items to Done, splitting oversized PBIs, or finding stale/blocked work. Prefers the
  Azure DevOps MCP server when connected, otherwise the `az boards` CLI (PowerShell-native).
---

# Azure Boards Organiser

Enables Claude Code to interact with Azure DevOps Boards using the Azure DevOps MCP server (preferred) or the `az boards` CLI. Covers reading and writing PBIs, Bugs, Tasks, sprint queries, and backlog management for a **Scrum** process template.

> **Shell**: all CLI examples are **PowerShell 7-native** (the user's primary shell). They use array-splatting for `az`, not bash `\` line continuations. Do not translate them back to bash.

---

## Configuration

Configuration resolves from `config.json` in this skill directory, with the machine's `az devops` defaults
as an optional convenience only:

1. **Org, project, team, iteration root, default area, tag taxonomy** — all from `config.json`. **`org` is
   required and must be passed explicitly on every `az` call** as `--organization $cfg.org`. Do not rely on
   `az devops configure --list`: a machine can legitimately have no default organization, and when it does,
   every `az boards` call fails with `--organization must be specified` — which reads like an auth problem
   and is not.

   ```powershell
   az devops configure --list   # informational only; may show no organization at all
   ```

2. `config.json` lives in this skill directory. This file is **gitignored** (it holds internal ADO structure). Copy the template and fill it in once:
   ```powershell
   Copy-Item "$HOME/.claude/skills/azure-boards-organiser/config.example.json" `
             "$HOME/.claude/skills/azure-boards-organiser/config.json"
   # then edit config.json with your real project / team / iterationRoot / areaPathDefault
   ```

`config.json` schema (see `config.example.json`):

| Key | Purpose | Example |
|-----|---------|---------|
| `org` | Organisation URL. **Required** — pass as `--organization` on every `az` call | `https://dev.azure.com/MyOrg` |
| `project` | Default project (overrides/supplies the `az` default) | `CloudPlatform` |
| `team` | Team name for `@CurrentIteration` and iteration queries | `CloudPlatform Team` |
| `iterationRoot` | Root iteration path for `UNDER` scoping | `CloudPlatform\Team\2026` |
| `areaPathDefault` | Default Area Path for new items | `CloudPlatform` |
| `tags` | Team tag taxonomy used for suggestions | `["bicep", "networking", …]` |

**At the start of any command**, read `config.json`. If it is missing, or `org` is absent from it, tell the user to copy `config.example.json` and fill it in, then stop — do not guess org/team/iteration values.

```powershell
$cfg = Get-Content "$HOME/.claude/skills/azure-boards-organiser/config.json" -Raw | ConvertFrom-Json
if (-not $cfg.org) { throw "config.json has no 'org'. Copy config.example.json and set it to your organisation URL." }
```

> **`--org` is not an accepted abbreviation for `--organization` on `az boards query`.** It fails with the
> same `--organization must be specified` message as passing nothing, so a typo here looks like a config
> problem. Always spell it out.

> **Flatten every WIQL here-string before passing it to `az`.** A `--wiql` value containing newlines is
> truncated at the first one on Windows, so every flag after it — including `--organization` — never reaches
> `az`. Append `-replace '\s*\r?\n\s*', ' '` to the here-string. Verified 2026-07-30 against four queries:
> all four failed un-flattened and all four succeeded flattened.

---

## Execution backend — selection order

Pick the backend per operation, in this order:

1. **Azure DevOps MCP server** — use it for **all reads and writes when it is connected** in the current session. It handles HTML field encoding, pagination, identity fields, and relations without shell quoting. Check the available tools/MCP servers list; if an Azure DevOps server is present, prefer its tools.
2. **`az boards` CLI (PowerShell-native)** — the documented fallback for normal field reads/writes when MCP is not connected. Works headless (e.g. a scheduled summary) and is fully reproducible.
3. **REST API** — only for operations CLI cannot do cleanly (e.g. work-item comments/discussion, some relation types). Note when you fall to this tier.

> The skill's CLI examples are the canonical, runnable form. When MCP is connected, the same intent applies — just call the MCP tool instead of shelling out.

---

## Prerequisites

- `az` CLI with the `azure-devops` extension: `az extension add --name azure-devops`
- Authenticated: `az login`. Setting a default organisation is **optional and not relied on** — `org` in `config.json` is the source of truth and is passed explicitly on every call (see Configuration).
- `config.json` present in this skill directory (see Configuration).

---

## Work Item Types (Scrum)

| Type | Parent | Key Fields |
|------|--------|------------|
| Epic | — | Title, Description, Area Path, Iteration Path, Tags |
| Feature | Epic | Title, Description, Area Path, Iteration Path, Tags |
| Product Backlog Item (PBI) | Feature | Title, Description, Acceptance Criteria, Story Points, Priority, Area Path, Iteration Path, Tags |
| Bug | Feature / PBI | Title, Repro Steps, Acceptance Criteria, Story Points, Priority, Area Path, Iteration Path, Tags |
| Task | PBI / Bug | Title, Description, Remaining Work, Activity, Area Path, Iteration Path |

> **Process customization caveat**: this skill assumes the out-of-the-box Scrum process. Orgs can rename/hide fields, add required fields, and restrict state transitions. Treat the field and state tables below as defaults — if a write is rejected, read the work item's actual fields/states (`az boards work-item show`) and adapt rather than assuming.

---

## Field Reference (Scrum)

| Friendly Name | WIQL Field Name | Notes |
|---------------|-----------------|-------|
| Title | System.Title | |
| State | System.State | New → Approved → Committed → Done / Removed |
| Work Item Type | System.WorkItemType | |
| Assigned To | System.AssignedTo | UPN or display name |
| Area Path | System.AreaPath | |
| Iteration Path | System.IterationPath | |
| Story Points | Microsoft.VSTS.Scheduling.StoryPoints | PBI/Bug |
| Effort | Microsoft.VSTS.Scheduling.Effort | Alias for Story Points in Scrum |
| Remaining Work | Microsoft.VSTS.Scheduling.RemainingWork | Tasks |
| Priority | Microsoft.VSTS.Common.Priority | 1 (high) – 4 (low) |
| Backlog Priority | Microsoft.VSTS.Common.BacklogPriority | Stack rank (lower = higher priority) |
| Acceptance Criteria | Microsoft.VSTS.Common.AcceptanceCriteria | HTML field |
| Description | System.Description | HTML field |
| Repro Steps | Microsoft.VSTS.TCM.ReproSteps | HTML field (Bug) |
| Tags | System.Tags | Semicolon-separated |
| Created Date | System.CreatedDate | |
| Changed Date | System.ChangedDate | |
| Parent | System.Parent | Work item ID of parent. Queryable but **read-only** — set parentage via `az boards work-item relation add --id <child> --relation-type parent --target-id <parent>`, never through `--fields`. |
| Time Spent (Completed Work) | Microsoft.VSTS.Scheduling.CompletedWork | Hours (cumulative total — see below) |
| Activity | Microsoft.VSTS.Common.Activity | Task: Development/Testing/… |

> **`CompletedWork` is a cumulative total, not an append log.** To "log 2h", read the current value, add 2, write the sum — never overwrite with the delta. See `/log-time`.

---

## HTML field handling

`Description`, `Acceptance Criteria`, and `Repro Steps` are stored as **HTML**.

- **Reading (for prompts)**: strip tags for display to save tokens.
- **Writing via MCP**: pass plain/markdown text; the server encodes it. Preferred.
- **Writing via CLI**: convert deterministically before passing as a `--fields` value:
  - Escape `&` → `&amp;`, `<` → `&lt;`, `>` → `&gt;` in text content **first**.
  - Wrap paragraphs in `<p>…</p>`.
  - Convert bullet/checklist lines to `<ul><li>…</li></ul>` (Acceptance Criteria render as a list, not a literal `- [ ]` string).
  - Keep the whole value single-quoted in PowerShell so `$`/backslashes are literal.

---

## Critical: Iteration Scoping

**ALWAYS** scope WIQL queries to the current or target iteration unless the user explicitly asks for all sprints.

```sql
-- CORRECT: scoped to current sprint (team macro)
WHERE [System.IterationPath] = @CurrentIteration('[<PROJECT>]\<TEAM>')

-- CORRECT: scoped to all items under the configured root
WHERE [System.IterationPath] UNDER '<iterationRoot>'

-- WRONG: returns everything across all iterations
WHERE [System.WorkItemType] = 'Product Backlog Item'
```

Find the current sprint name:
```powershell
az boards iteration team list --team $cfg.team --timeframe current --organization $cfg.org --query '[0].name' -o tsv
```

---

## WIQL Patterns

See `references/wiql-patterns.md` for query templates. Load that file when constructing non-trivial WIQL.

> **WIQL has no SQL subqueries.** You cannot write `WHERE [System.Parent] IN (SELECT …)`. Also, **`az boards query` runs flat queries only** (*"Only supports flat queries"*) — `WorkItemLinks` queries need the MCP server or REST `wiql` endpoint. To get children via the CLI, use a flat single-parent query (`WHERE [System.Parent] = <ID>`) or a two-step: run the parent query, collect the IDs, then `WHERE [System.Parent] IN (id, id, id)` with literal IDs. See the parent/child section of `wiql-patterns.md`.

---

## PowerShell CLI Cheatsheet

`az` is a native executable — splat an **argument array** (`az @azArgs`) rather than using backtick line continuations (fragile with trailing whitespace). `--fields` takes **multiple `Name=Value` arguments**; pass them as an array, never comma-joined. Avoid the automatic `$args` variable name — use `$azArgs`.

```powershell
$cfg = Get-Content "$HOME/.claude/skills/azure-boards-organiser/config.json" -Raw | ConvertFrom-Json

# Get a work item by ID (parse JSON, never text)
$wi = az boards work-item show --id $Id --organization $cfg.org -o json | ConvertFrom-Json

# Run a WIQL query. The single-quoted here-string keeps $, @, \ literal; the trailing
# -replace flattens it to one line, without which --organization is silently lost.
$wiql = @'
SELECT [System.Id], [System.Title], [System.State]
FROM WorkItems
WHERE [System.WorkItemType] = 'Product Backlog Item'
  AND [System.AssignedTo] = @Me
'@ -replace '\s*\r?\n\s*', ' '
$result = az boards query --wiql $wiql --project $cfg.project --organization $cfg.org -o json | ConvertFrom-Json

# Create a PBI (--fields as an array; HTML escaped + wrapped)
$fields = @(
  'Microsoft.VSTS.Scheduling.StoryPoints=5'
  'Microsoft.VSTS.Common.Priority=2'
  'Microsoft.VSTS.Common.AcceptanceCriteria=<ul><li>Given X, when Y, then Z</li></ul>'
  'System.Tags=networking; bicep'
)
$azArgs = @(
  'boards','work-item','create'
  '--organization', $cfg.org
  '--project', $cfg.project
  '--title','Configure hub VNet peering to route spoke egress through Azure Firewall'
  '--type','Product Backlog Item'
  '--area', $cfg.areaPathDefault
  '--iteration', "$($cfg.iterationRoot)\Sprint 42"
  '--fields'
) + $fields
$created = az @azArgs -o json | ConvertFrom-Json

# Update fields on an existing work item
$fields = @('System.State=Approved', 'Microsoft.VSTS.Scheduling.StoryPoints=5')
$azArgs = @('boards','work-item','update','--id', $Id, '--organization', $cfg.org, '--fields') + $fields
az @azArgs -o json | ConvertFrom-Json | Out-Null

# Create a child Task under a PBI, then parent it via a relation
# (System.Parent is read-only — set parentage with `relation add`, not --fields):
$fields = @(
  'Microsoft.VSTS.Scheduling.RemainingWork=4'
  'Microsoft.VSTS.Common.Activity=Development'
)
$azArgs = @('boards','work-item','create','--project', $cfg.project,'--organization', $cfg.org,'--title','Author Bicep module','--type','Task','--fields') + $fields
$task = az @azArgs -o json | ConvertFrom-Json
az boards work-item relation add --id $task.id --relation-type parent --target-id $ParentId --organization $cfg.org -o json | ConvertFrom-Json | Out-Null
```

---

## Commands

| Command | Purpose |
|---------|---------|
| `/new-pbi` | Draft and create a new PBI from a plain-language description. |
| `/prepare-pbi <ID>` | Analyse, enrich, and optionally decompose a PBI into Tasks. |
| `/split-pbi <ID>` | Split an oversized/vague PBI into child or replacement PBIs. |
| `/prioritize-backlog` | Greedily fill a sprint from the stack-ranked approved backlog. |
| `/my-sprint-work` | Show my PBIs and Tasks in the current sprint. |
| `/daily-standup` | Standup view: done since yesterday, in progress, blockers. |
| `/log-time <TASK_ID>` | Add hours to a Task's CompletedWork; adjust RemainingWork. |
| `/move-to-done <ID>` | Validate and transition a PBI/Task to Done. |
| `/blocked-work` | Find blocked / at-risk items in the current sprint. |
| `/find-stale` | Backlog hygiene: stale, unpointed, orphaned, mis-stated items. |
| `/sprint-summary [Sprint]` | Sprint health snapshot — velocity, completion, risks. |
| `/sprint-retro [Sprint]` | End-of-sprint retro: committed vs done, carry-over, notes. |

---

## PBI Quality Checklist

When analysing or enriching a PBI, evaluate against these criteria:

### Title
- [ ] Descriptive (more than 5 words)
- [ ] States what needs to be done, not how
- [ ] Avoids vague terms: "fix", "update", "improvements", "misc"

### Description
- [ ] Exists and is non-empty
- [ ] Explains **what** and **why** (business context/value)
- [ ] References relevant resources (linked items, docs, decisions)

### Acceptance Criteria
- [ ] Populated and specific
- [ ] Each criterion is independently testable
- [ ] Uses Given/When/Then or clear bullet format
- [ ] Does NOT include trivially obvious criteria ("deployment succeeds", "no errors in logs")

### Sizing & Scheduling
- [ ] Story Points assigned (if Approved or Committed)
- [ ] Iteration Path set to correct sprint
- [ ] Area Path reflects correct team/component

### Tags
- [ ] Tagged appropriately for filtering, from the `tags` taxonomy in `config.json`

---

## Iteration Path Conventions

```
<iterationRoot>\<SprintName>   # e.g. CloudPlatform\Team\Sprint 42

# Inspect iterations
az boards iteration project list --depth 3 --project $cfg.project --organization $cfg.org
az boards iteration team list --team $cfg.team --project $cfg.project --organization $cfg.org
```

---

## Notes

- Strip HTML from Description/AcceptanceCriteria before including in prompts to save tokens. Re-encode (escape + `<p>`/`<ul>`) when writing back via CLI.
- BacklogPriority is a float; lower value = higher stack rank. Do not set it manually — `/prioritize-backlog` recommends *iteration assignment*, it does not reorder the stack rank.
- `@CurrentIteration('[Project]\Team')` requires the team context argument and exact name matching — verify with `az boards iteration team list`.
- WIQL has no `LIMIT`, and `az boards query` has no `--top`. Cap client-side (`| Select-Object -First <N>`) or with a `--query` JMESPath slice.
- `@Me` resolves to the authenticated user; `@Today-7` for relative dates.
