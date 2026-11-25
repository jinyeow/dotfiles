---
initiative: <PBI-id>-<slug>
type: status
updated: YYYY-MM-DD
stale_after: YYYY-MM-DD  # updated: + 7 days
generated:
  by: <agent-or-session>
  at: YYYY-MM-DDTHH:MM:SSZ
---

# <Initiative title> — STATUS

> The single volatile source of truth. Auto-loaded every session. Current-state only; history goes to
> `log.md` (this initiative) and git. Keep this file under about 60 lines. If `updated:` above is more
> than ~7 days old, distrust this and say so before acting.

## Now
<where we are / what was just done. 5 lines max.>

## Repos
| Repo | Worktree | Branch | Item | PR | State |
|---|---|---|---|---|---|
| <repo> | <worktree folder> | <type>/<item>-<slug> | <work item id> | <PR link or "none"> | <active / in review / merged> |

## Blocked on
<what's stopping the next action, or "nothing".>

## Next action
<imperative, one per active workstream. What a resuming session should do first.>
