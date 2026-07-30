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

1. **Direct** — the initiative key whose leading digit run equals the work-item ID (`790001` →
   `790001-arc-cisco-access`).
2. **Via parent** — on a miss, retry with the item's `System.Parent`. The SNOW PBIs all hang off Feature
   `786545` and match only this way.

> **Each pass must resolve to exactly one key.** Take the key's *maximal* leading run of digits and compare
> it to the ID as a whole number — not as a string prefix. `786` does not match `786545-snow-access-requests`,
> because that key's digit run is `786545`. Then: **one** match resolves the pass; **zero** matches fall
> through to the next pass; **two or more** matches are reported as an ambiguous join and the item is
> **unknown** — never resolved by iteration order, which is arbitrary (see `core.md` on `registry.json` key
> order deciding overlapping globs).

> **A parent-pass match is not evidence about the child.** After a pass-2 match, confirm the item's own ID
> appears somewhere in that initiative's files before trusting the initiative's blocker content for it.
> If the ID appears nowhere, the item is **unknown** — an initiative's blockers cover its own headline work,
> not automatically every child PBI.

> **The order is load-bearing — pass 1 must win.** Feature `786545` is the parent of 9 of the 15 live items,
> including `790001` and `793186`, which have initiatives of their own. Consulting the parent first (or
> letting it override) collapses those two into `786545-snow-access-requests` and attaches the wrong
> `Blocked on` to both. Only use the parent when the direct ID match has already failed.

Anything still unmatched is **uncovered**: list it, and say the brain has no context for it rather than
guessing from the title.

> **The ADO title is not a join validator.** PBI `790487` is titled "Investigate two things about EDI
> database access" while its initiative is the SQL permissions audit — the initiative's own `STATUS.md`
> confirms the link. Trust the ID, not the wording.

For each matched item read that initiative's `STATUS.md` **in full** — Step 4 searches the whole file for the
item's ID — but *report* from two things only: **`Blocked on`** and **`Next action`**. Reading the rest is
for locating the ID and reading the sentence that names it; it is not licence to summarise other sections.

> **The blocker section is not always called `Blocked on`.** `790001-arc-cisco-access` uses `## Open`
> instead. Fall back to `## Open` when `## Blocked on` is absent. Step 4 alone decides the next actor — this
> step supplies the text and never classifies.

> **`STATUS.md` files are hand-maintained and lag ADO.** If the front-matter `updated:` is more than 7 days
> before today, mark the item **untrusted** — surface what it says, labelled as possibly stale, and never
> present it as current fact. Step 4 rule 3 decides the bucket for it. Where live ADO and a `STATUS.md`
> disagree, ADO wins.

## Step 4: Work out the load

Classify each item by **who must act next** into exactly one of three buckets — `you`, `other`, `unknown` —
by walking this list in order and stopping at the **first** rule that fires. The rules are exhaustive, so
every item lands in exactly one bucket, and no two can both decide an item:

1. No initiative matched in either pass → **unknown**.
2. The join was ambiguous (two or more keys matched a pass, per Step 3) → **unknown**.
3. **Trust gate.** The matched initiative's `STATUS.md` front-matter `updated:` is more than 7 days before
   today → **unknown**. This sits above every rule that reads the file's content, so an untrusted file is
   never classified from what it says — surface its text labelled possibly stale, but do not derive an actor
   from it.
4. The match came from pass 2 (parent) and the item's own ID appears nowhere in that initiative's files →
   **unknown**.
5. The item's own ID is named nowhere in the file — not in `Blocked on`, `Next action`, `Now`, or a task map
   → **unknown**. There is no evidence either way; do not infer from the initiative's general posture.
6. The file has neither a `## Blocked on` nor an `## Open` section, **and** the ID is named only outside
   `Next action` → **unknown**. With no blocker section and no next-action mention, there is nothing to infer
   an actor from.
7. The blocker or next-action text that names this item's ID identifies another person, team, vendor, or an
   external decision as the party being waited on → **other**.
8. Otherwise → **you**. (The ID is named, the file is trusted, and nothing external is named as the party
   being waited on — including the case of an empty blocker section, or one naming only something you do.)

Rules 1–6 are the unknown gates; 7 and 8 split everything that survives them.

> **Illustrative only — verdicts dated 2026-07-30. Always re-derive from the current files; never carry a
> verdict below into a run.** 786549 was `Blocked` in ADO and absent from 786545's `Blocked on`, but its
> `Next action` named it and said the hold was lifted and the PRs needed shepherding — rule 8, **you**.
> 789905, 789906 and 789911 hung off Feature 786545 and matched the join, but the initiative's `STATUS.md`
> never mentioned them — rule 5, **unknown**.

> **The "live ADO wins over `STATUS.md`" rule is scoped to item state — not to who acts next.** ADO is
> authoritative for state, column, assignment and PR status. It carries no next-actor field at all, so the
> brain is the *only* source for that, and an ADO state of `Blocked` does not by itself make the next actor
> someone else. 786549 was the worked example — `Blocked` in ADO, next actor you, as at 2026-07-30; re-derive
> it, do not assume it still holds.

Report the **unknown** count separately and do **not** fold it into the load. Say so explicitly when it is
non-zero, because unknowns make the band *understate* the true load — a band computed against six unknowns
is a floor, not a measurement. If the unknown count rivals the you-count, the most valuable output of the
run is the list of unknowns, not the band.

Count only the *next-actor-is-you* items and apply the load bands from `core.md`. Do not substitute a raw
open-item count: the Blocked column is mostly other people's queues, not your load.

## Step 5: Enrich the shortlist only

The rubric ranks on facts `STATUS.md` does not carry — an unanswered question on a work item, and a PR open
with a clean merge preview and no reviewer vote. Fetch those, **read-only**, and only for the handful of
*next-actor-is-you* candidates actually being ranked. Never for the whole board: this is a per-item round
trip and the `other` and `unknown` items are not eligible for the top three anyway.

```powershell
# $shortlist = the next-actor-is-you IDs from Step 4 (a handful, not the board)
foreach ($id in $shortlist) {
  $wi = az boards work-item show --id $id --expand relations --organization $org -o json | ConvertFrom-Json

  # Linked PRs arrive as ArtifactLink relations: vstfs:///Git/PullRequestId/{project}%2F{repo}%2F{prId}
  # The PR id is the URL-decoded last segment — this parse is load-bearing.
  $prIds = $wi.relations |
    Where-Object { $_.url -like 'vstfs:///Git/PullRequestId/*' } |
    ForEach-Object { ([System.Uri]::UnescapeDataString($_.url) -split '/')[-1] }

  foreach ($prId in $prIds) {
    $pr = az repos pr show --id $prId --organization $org -o json | ConvertFrom-Json
    # Rubric rule 3 ("ready to land") needs all three: $pr.status, $pr.mergeStatus, $pr.reviewers.vote
  }
}
```

`status = active` **and** `mergeStatus = succeeded` **and** every `reviewers[].vote` equal to `0` is the only
shape that satisfies "ready to land". A merged PR does not satisfy it, and does not unblock an item —
`core.md` records four SNOW PRs that merged while their items stayed Blocked on substance.

> **An empty `reviewers` array counts as "no reviewer vote".** Both shapes qualify — nobody assigned, and
> assigned-but-not-voted — because in each the work is spent and only shepherding remains; they differ only
> in *what* the shepherding is (assign a reviewer, versus chase the one already on it). Say which of the two
> it is, since it changes the action. Verified live 2026-07-30: of five ready-to-land PRs on one item, four
> had no reviewers at all and one had an assigned reviewer on vote `0`.

Work-item comments have no clean `az boards` verb, so they fall to the **REST tier** (SKILL.md → Execution
backend, order 1 MCP → 2 CLI → 3 REST). Prefer the Azure DevOps MCP server's comment tool when connected;
otherwise:

```powershell
# REST tier — note the tier in the run. Verified live 2026-07-30 (returned 4 comments for 399442).
$azArgs = @(
  'rest','--method','get'
  '--resource','499b84ac-1321-427f-aa17-267ca6975798'
  '--url', "$org/$($cfg.project)/_apis/wit/workItems/$id/comments?api-version=7.1-preview.3"
)
$comments = az @azArgs -o json | ConvertFrom-Json
```

> **Reads only.** No `az boards work-item update`, no `az repos pr set-vote`, no comment posted. Triage
> observes PR and comment state; it never touches it.

> **Evidence-or-skip.** A rubric rule may be applied **only** with a citable fact behind it. Absent that
> fact the rule does not apply at all and ranking falls through to the next rule — never inferred from tone,
> urgency of wording, or an initiative's general posture. The citable fact per rule:
>
> 1. *Unblocks more than one initiative* — the same blocker, named in two initiatives' files, both cited.
> 2. *Someone external is waiting* — a specific work-item comment, quoted, with no later reply.
> 3. *Ready to land* — a PR id plus its `status` / `mergeStatus` / `reviewers[].vote`.
> 4. *Explicitly named as the next step* — the `Next action` line, quoted, with the blocker section empty.
> 5. *Everything else* — the fall-through; needs nothing.
>
> If the enrichment call fails or returns nothing, that is an absent fact, not a negative one: rules 2 and 3
> simply do not apply. Say which rule decided each recommendation, and if the rubric cannot separate two
> candidates, call them tied rather than breaking the tie on something the rubric does not contain.

## Step 6: Output

One report, **≈400 words maximum**. Prose stays out; every line is a row or a recommendation.

Shape only — the IDs below are **fake placeholders**, not a cached answer. Never carry a row from this
template into a real run.

```
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
 BOARD TRIAGE
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
 Load: AMBER — 4 items where the next actor is you
        (4 parked on others, 3 unknown — the band is a floor)

 In Development (3)
   1234  Configure hub VNet peering           you    decision on the prd block
   1240  Author Bicep peering module          you    PR open, no reviewer vote
   1248  Retire legacy agent VMs              ?      STATUS 16d old — untrusted

 Blocked (8)
   1251  Wire spoke egress through firewall   you    next action names it
   1253  Re-point the export job              you    blocker section empty
   1255  Grant read on the reporting DB       other  awaiting vendor
   1260  Create privileged admin account      other  no UPN from the caller
   1266  Migrate archive storage accounts     ?      no initiative in the brain
   1271  Decommission the staging subnet      ?      ID not named in STATUS
   … +2 more (0 you, 2 other, 0 ?)

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
  and the single reason it is where it is. **At most 6 rows per section.** Order rows `you`, then `other`,
  then `?`, and ascending by ID within each group — not by `ChangedDate`, which is noise here (Step 2). Keep
  the first 6 in that order, then a final line `… +N more (M you, M other, M ?)` giving the dropped count;
  never silently truncate. The ordering is fixed so two runs over the same board show the same rows.
- **Do next** — **exactly three**, ranked. Each names the *one* rubric constraint that puts it there, in
  plain words. Items whose next actor is not you are never eligible — route those to a chase instead. If
  fewer than three are eligible, say so rather than padding with ineligible items.

## Step 7: Offer next actions

Triage recommends; it does not act. Hand off:

- `"Show me <ID>"` → read the item and its initiative in full.
- `"Chase <ID>"` → draft the message to whoever the next actor is (no work-item write).
- `"Review blockers in this sprint"` → `/blocked-work`.

Do not offer state transitions, tag edits, or a `STATUS.md` update from this command.
