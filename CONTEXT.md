# Dotfiles

Personal cross-platform dotfiles and agentic-coding tooling (Claude Code / Codex / Pi skills, agents, hooks). This glossary covers vocabulary specific to the agent-workflow tooling in this repo — not general programming terms.

## Language

**Frontier**:
The set of tickets in a ticket breakdown whose blockers are all done — the tickets that can start right now. Defined by the `to-tickets` skill; the fleet launcher works this set.
_Avoid_: Ready tickets, unblocked tickets

**Likely files**:
An optional field on a ticket (from `to-tickets`) listing the files a ticket is predicted to touch, filled in during the ticket-drafting exploration pass. Consumed only by the fleet launcher's pre-launch overlap check — never passed to the implementer as a scope restriction.
_Avoid_: Scoped files, allowed files, file lock

**Generation-time gap**:
A quality problem that occurs because a skill produces text as a side effect of some other task ("open a PR", "create a ticket") whose task frame never matches a prose-quality skill's trigger description, so the auto-trigger never fires. Closed only by having the producing skill explicitly call the prose-quality skill as a step in its own flow — not by broadening the prose-quality skill's trigger description.
_Avoid_: Detection gap (the opposite case: a human or reviewer re-reading finished text and noticing it after the fact, which auto-trigger broadening *does* help with)

**Tell Catalog**:
The `write` skill's pattern-matching layer (`references/write-en.md`): a catalog of AI-sounding wording (filler phrases, formulaic structures, vague declaratives, em-dashes, and similar) to scan for and cut. Applies to any text another human will read, down to a single sentence — commit messages, code comments, config comments, in-repo docs, PR and ticket descriptions included. Does not apply to auto-generated boilerplate, test fixture/sample data, log messages, or error messages.
_Avoid_: de-AI checklist, tell removal (the skill explicitly rejects "checklist" framing — see its Core Stance)

**Document Modes**:
The `write` skill's second layer: its four Modes (Long-form Article, Release Note Template, Document Review, Paragraph Coherence), each doing a different kind of prose-document work — structural cuts, templating, a review checklist, flow diagnosis. Fire only on genuine prose documents — reports, docs, README, release notes, articles — never on single-line artifacts like a commit message or code comment.
_Avoid_: prose polishing, structural pass (the skill already uses "polish" for a different, sentence-level meaning, and "structural" only describes one of the four Modes)
