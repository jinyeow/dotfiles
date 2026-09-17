# Add a per-initiative `log.md` to the project-brain contract

## Status

Accepted. Governs `ai-agents/skills/project-brain/SKILL.md` and
`ai-agents/AGENTS.d/project-brain.md` across all registered brain repos.

## Context

The project-brain contract said `STATUS.md` is current-state only and history goes to the
brain's root `log.md`. Sessions did not follow it. They appended full session narratives to
`STATUS.md` instead.

Measured on 2026-09-17 in one registered brain's `initiatives/` directory, before cleanup:

| Initiative | STATUS.md lines |
|---|---|
| A | 2089 |
| B | 1513 |
| C | 1232 |
| D | 972 |
| E | 393 |
| F | 201 |
| G | 200 |
| H | 110 |

The brain's `STATUS.md` template asks for "5 lines max" under `## Now`. `STATUS.md`
auto-loads into every session in a matching worktree, so each of these files cost context on
every session start and buried the real current state. One initiative had no `## Now` or
`## Blocked on` heading at all.

The likely cause: the contract gave detailed session history no home. The old "On session
close" text allowed only 2-5 lines in a root log shared by every initiative. A resuming
session needs more detail than that, so the detail went to the only per-initiative file that
was open: `STATUS.md`.

A cleanup pass moved each history verbatim into a new `initiatives/<id>/log.md` and rewrote
`STATUS.md` to the template shape. Nothing in the skill, the templates, or the brain's own
ADR for the project-brain design mentioned `initiatives/<id>/log.md`. Left as is, the next
session close would follow the old contract text as written, find the detail has nowhere
sanctioned to go, and regrow `STATUS.md`.

## Decision

Add a per-initiative `log.md` to the contract as the sanctioned home for session history.

- A per-initiative `log.md` holds session history for that initiative. It is read on demand,
  never auto-loaded.
- `STATUS.md` holds current state only, under a soft cap of about 60 lines.
- The per-initiative `log.md` is the same reserved-role filename as the brain-root `log.md`
  and carries no `type:` frontmatter field.
- On session close, the order is: refresh `STATUS.md` to current state only and move any
  history out of it into the initiative `log.md`; append the session narrative to the
  initiative `log.md` (a dated heading, what was done, evidence, links); append 2-5 lines to
  the brain's root `log.md` as before; commit; delete duplicates.
- New-initiative and new-area scaffolding create `log.md` from a template alongside
  `core.md` and `STATUS.md`.

## Alternatives considered

- **Everything in the root `log.md`.** About 5000 lines of accumulated history would swamp a
  journal meant for short, 2-5 line cross-initiative entries. Rejected.
- **Git history only, no narrative file.** Git history cannot be grepped as a narrative, and
  rewriting `STATUS.md` on every status update loses the per-session framing a resuming
  session needs. Rejected.
- **Keep the narrative in `STATUS.md`.** This is the status quo that produced the measured
  bloat above. Rejected.
