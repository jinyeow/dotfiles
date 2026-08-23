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

**OKF bundle**:
The Open Knowledge Format (Google, v0.2) unit a single `okf_version` declaration governs. Per `project-brain`'s adoption (#195), the whole brain repo (e.g. `E:\Personal Projects\brain\`) is one bundle — its root `index.md` declares `okf_version: "0.2"`; per-initiative directories (`initiatives/<id>/`) are not separate bundles and get no `index.md` of their own.
_Avoid_: brain (ambiguous — could mean the repo, an initiative, or the concept generally); OKF instance

**OKF concept**:
A single Markdown file with a `type:` frontmatter field, per the Open Knowledge Format. Every non-reserved `.md` file under a brain (`core.md`, `STATUS.md`, `adr/*.md`, `research/*.md`, `reports/*.md`) is a concept; `index.md` and `log.md` are reserved filenames and are not concepts.
_Avoid_: document, page (too generic — "concept" is OKF's own term and is what a consumer routes on via `type:`)
