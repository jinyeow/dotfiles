---
description: Personal triage over the whole board — what's in flight, what's blocked, what to do next, and whether the load is too high. Joins live ADO against the project-brain initiative files. Read-only.
---

# Board Triage

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

If an Azure DevOps MCP server is connected this session, use its tools for all reads; otherwise use the
PowerShell `az` blocks below.

`/board-triage` — no arguments.

> **Read-only, in both directions.** This command never changes work-item state, and it never writes a
> priority snapshot back into the brain. ADO is the system of record for item state and priority; a second
> copy in a `STATUS.md` goes stale within days, which is the failure mode this triage policy exists to
> avoid. Report, then stop.

> **Not sprint-scoped.** Unlike `/daily-standup` and `/blocked-work`, triage deliberately ignores the
> iteration — the question is "what is open on me", and blocked work routinely sits outside the active
> sprint.

## Step 1: Load the triage policy

Read the policy file explicitly — **do not assume it is already in context**:

```
E:/HollardInsuranceRetail/brain/initiatives/board-triage/core.md
```

The project-brain SessionStart hook injects it only when the session cwd is the estate root
`E:/HollardInsuranceRetail`. From any repo subdirectory a *different* initiative loads and this file is
absent, so a run that relies on the hook silently has no rubric.

Take the **prioritisation rubric** and the **load policy** from that file verbatim. Do not invent, extend
or reweight criteria — if the rubric does not separate two candidates, say they are tied.

## Step 2: Query the board

Items assigned to me that are either sitting in the *In Development* Kanban column or in state *Blocked*.

> **`In Development` is a column, not a state.** Items in it are in state `Committed`. Querying
> `[System.State] = 'In Development'` returns nothing — use `[System.BoardColumn]`. `Blocked` is both a
> state and a column, so either field works for it.

> **Flatten the WIQL to a single line before passing it to `az`.** A multi-line `--wiql` value is
> truncated at the first newline on Windows, so the flags that follow it never reach `az` and it fails
> with `--organization must be specified`. The `-replace` below is load-bearing, not cosmetic.

```powershell
$wiql = @'
SELECT [System.Id], [System.Title], [System.WorkItemType], [System.State], [System.BoardColumn],
       [System.AreaPath], [System.IterationPath], [System.ChangedDate], [System.Tags], [System.Parent]
FROM WorkItems
WHERE [System.AssignedTo] = @Me
  AND ([System.BoardColumn] = 'In Development' OR [System.State] = 'Blocked')
  AND [System.State] NOT IN ('Done', 'Removed')
ORDER BY [System.ChangedDate] DESC
'@ -replace '\s*\r?\n\s*', ' '
$items = az boards query --wiql $wiql --project $cfg.project --organization $org -o json | ConvertFrom-Json
```

> **A uniform `ChangedDate` across many items is noise, not activity.** A bulk same-day refresh usually
> means somebody reordered `Microsoft.VSTS.Common.BacklogPriority`. Do not read it as progress, and do not
> use days-since-change as a triage signal here.

## Step 3: Join each item to its initiative

Read `E:/HollardInsuranceRetail/brain/registry.json`. Resolve each work-item ID to an initiative in **two
passes** — one pass alone leaves most of the board unmatched:

1. **Direct** — the initiative key whose leading digits equal the work-item ID (`790001` →
   `790001-arc-cisco-access`).
2. **Via parent** — on a miss, retry with the item's `System.Parent`. The SNOW PBIs all hang off Feature
   `786545` and match only this way.

> **The order is load-bearing — pass 1 must win.** Feature `786545` is the parent of 9 of the 15 live items,
> including `790001` and `793186`, which have initiatives of their own. Consulting the parent first (or
> letting it override) collapses those two into `786545-snow-access-requests` and attaches the wrong
> `Blocked on` to both. Only use the parent when the direct ID match has already failed.

Anything still unmatched is **uncovered**: list it, and say the brain has no context for it rather than
guessing from the title.

> **The ADO title is not a join validator.** PBI `790487` is titled "Investigate two things about EDI
> database access" while its initiative is the SQL permissions audit — the initiative's own `STATUS.md`
> confirms the link. Trust the ID, not the wording.

For each matched item read that initiative's `STATUS.md` and take two things only: **`Blocked on`** and
**`Next action`**.

> **The blocker section is not always called `Blocked on`.** `790001-arc-cisco-access` uses `## Open`
> instead. Fall back to `## Open` when `## Blocked on` is absent; if neither exists, treat the item's next
> actor as unknown rather than inferring one from `Next action` alone.

> **`STATUS.md` files are hand-maintained and lag ADO.** If the front-matter `updated:` is more than 7 days
> before today, mark the item **untrusted** — surface what it says, labelled as possibly stale, and never
> present it as current fact. Where live ADO and a `STATUS.md` disagree, ADO wins.

## Step 4: Work out the load

Classify each item by **who must act next**, from its `Blocked on` (or `Open`) section:

- `Blocked on` empty, or names something only you can do → **next actor is you**.
- `Blocked on` names another person, team, vendor, or an external decision → **next actor is someone else**.
- Uncovered, or the initiative's `STATUS.md` is untrusted → **unknown**.

> **Then the named-anywhere fallback, which decides more items than the rule above.** An initiative's
> `Blocked on` covers its own headline work, not necessarily every child PBI. So when an item is *not* named
> in `Blocked on`, search the whole `STATUS.md` for its ID before giving up:
>
> - **Named anywhere** — in `Next action`, `Now`, a task map — classify from what that text says. Example:
>   786549 is `Blocked` in ADO and absent from 786545's `Blocked on`, but its `Next action` says the hold is
>   lifted and the PRs need shepherding, so its next actor is **you**.
> - **Not named at all** → **unknown**. Example: 789905, 789906 and 789911 hang off Feature 786545 and match
>   the join, but the initiative's `STATUS.md` never mentions them, so there is no evidence either way. Do
>   not infer a next actor from the parent initiative's general posture.

> **The "live ADO wins over `STATUS.md`" rule is scoped to item state — not to who acts next.** ADO is
> authoritative for state, column, assignment and PR status. It carries no next-actor field at all, so the
> brain is the *only* source for that, and an ADO state of `Blocked` does not by itself make the next actor
> someone else. 786549 is the worked example: `Blocked` in ADO, next actor you.

Report the **unknown** count separately and do **not** fold it into the load. Say so explicitly when it is
non-zero, because unknowns make the band *understate* the true load — a band computed against six unknowns
is a floor, not a measurement. If the unknown count rivals the you-count, the most valuable output of the
run is the list of unknowns, not the band.

Count only the *next-actor-is-you* items and apply the load bands from `core.md`. Do not substitute a raw
open-item count: the Blocked column is mostly other people's queues, not your load.

## Step 5: Output

One report, **≈400 words maximum**. Prose stays out; every line is a row or a recommendation.

Shape only — the IDs below are **fake placeholders**, not a cached answer. Never carry a row from this
template into a real run.

```
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
 BOARD TRIAGE
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
 Load: AMBER — 4 items where the next actor is you
        (3 parked on others, 2 unknown — the band is a floor)

 In Development (3)
   1234  Configure hub VNet peering           you    decision on the prd block
   1240  Author Bicep peering module          you    PR open, no reviewer vote
   1248  Retire legacy agent VMs              ?      STATUS 16d old — untrusted

 Blocked (6)
   1251  Wire spoke egress through firewall   you    next action names it
   1255  Grant read on the reporting DB       other  awaiting vendor
   1260  Create privileged admin account      other  no UPN from the caller
   …
   1266  Migrate archive storage accounts     —      no initiative in the brain

 Do next
   1. 1234 — clears two initiatives at once: the same placeholder-member
      decision also unblocks 1251.
   2. 1240 — the work is already spent; only a reviewer vote is missing.
   3. 1251 — its own Next action names it, with Blocked on empty.
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
```

Rules for the sections:

- **Load line** — band colour, then the next-actor-is-you count. Carry the parked and unknown counts in
  parentheses so the band is auditable. If the band is Red, add the one line `core.md` prescribes: close
  the cheapest two before opening anything new.
- **In Development** and **Blocked** — one row each: ID, short title, next actor (`you` / `other` / `?`),
  and the single reason it is where it is. Cap long lists and say how many were dropped; never silently
  truncate.
- **Do next** — **exactly three**, ranked. Each names the *one* rubric constraint that puts it there, in
  plain words. Items whose next actor is not you are never eligible — route those to a chase instead. If
  fewer than three are eligible, say so rather than padding with ineligible items.

## Step 6: Offer next actions

Triage recommends; it does not act. Hand off:

- `"Show me <ID>"` → read the item and its initiative in full.
- `"Chase <ID>"` → draft the message to whoever the next actor is (no work-item write).
- `"Review blockers in this sprint"` → `/blocked-work`.

Do not offer state transitions, tag edits, or a `STATUS.md` update from this command.
