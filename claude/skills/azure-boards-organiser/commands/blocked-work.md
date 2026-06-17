---
description: Find blocked and at-risk items in the current sprint — tagged-blocked plus committed-but-stalled, with confirm-first remediation.
---

# Blocked Work

Load this skill's `SKILL.md` (azure-boards-organiser) and resolve config (see SKILL.md → Configuration).

```powershell
$cfg = Get-Content "$HOME/.claude/skills/azure-boards-organiser/config.json" -Raw | ConvertFrom-Json
```
Resolve org from `az devops configure --list`. If `config.json` is missing, stop and tell the user to copy `config.example.json` to `config.json` and fill it in.

If an Azure DevOps MCP server is connected this session, use its tools for all reads/writes; otherwise use the PowerShell `az` blocks below.

`/blocked-work` — no arguments.

> **Blocked-ness has no native Scrum field.** It is *inferred* from a `blocked` tag and/or stalled signals (a Committed item with no change in N days). Treat both as heuristics, not ground truth.

## Step 1: Tagged blocked (active sprint)

Run the "Tagged blocked, active sprint" pattern from `references/wiql-patterns.md`.

```powershell
$wiql = @'
SELECT [System.Id], [System.Title], [System.WorkItemType], [System.State],
       [System.AssignedTo], [System.Tags], [System.ChangedDate]
FROM WorkItems
WHERE [System.Tags] CONTAINS 'blocked'
  AND [System.State] NOT IN ('Done', 'Removed')
  AND [System.IterationPath] = @CurrentIteration('[<PROJECT>]\<TEAM>')
ORDER BY [System.ChangedDate]
'@ -replace '<PROJECT>', $cfg.project -replace '<TEAM>', $cfg.team
$blocked = az boards query --wiql $wiql --project $cfg.project -o json | ConvertFrom-Json
```

## Step 2: At-risk — committed but stalled

Run the "At-risk — committed but stalled (no change in N days)" pattern (default N = 3). Compute days-since-change client-side from `System.ChangedDate` after `ConvertFrom-Json`.

```powershell
$wiql = @'
SELECT [System.Id], [System.Title], [System.State], [System.AssignedTo],
       [System.ChangedDate], [Microsoft.VSTS.Scheduling.RemainingWork]
FROM WorkItems
WHERE [System.State] = 'Committed'
  AND [System.ChangedDate] < @Today - 3
  AND [System.IterationPath] = @CurrentIteration('[<PROJECT>]\<TEAM>')
ORDER BY [System.ChangedDate]
'@ -replace '<PROJECT>', $cfg.project -replace '<TEAM>', $cfg.team
$atRisk = az boards query --wiql $wiql --project $cfg.project -o json | ConvertFrom-Json
```

## Step 3: (Optional) No owner

Optionally surface Committed items with no owner so the blocker isn't simply "nobody's on it" — run the "Active items with no owner" pattern from `references/wiql-patterns.md`.

## Step 4: Output

Two sections — **Blocked** (tagged) and **At-risk** (stalled) — each row: ID — Title — Owner — days since change. Cap long lists and note truncation; never silently drop rows.

```
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
 BLOCKED & AT-RISK  (current sprint)
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
 Blocked (tagged):
   1234  Wait on firewall change ticket   alice   9d
   …
 At-risk (Committed, no change ≥3d):
   1240  Author Bicep peering module      bob     5d
   …
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
```

## Step 5: Offer next actions

All writes are **confirm-first**:

- **Add / remove `blocked` tag** — read `System.Tags`, edit the semicolon-separated list, write back: `az boards work-item update --id <ID> --fields 'System.Tags=blocked; networking'`.
- **Reassign** — `az boards work-item update --id <ID> --fields System.AssignedTo=<upn>`.
- **Escalate (leave a comment)** — CLI comment support is limited; prefer the MCP server, falling back to REST per SKILL.md's backend order. Note the tier used.
