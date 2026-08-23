# Adopt the Open Knowledge Format for `project-brain` markdown

## Status

Accepted. Governs the frontmatter schema, link syntax, and bundle structure of every
`project-brain` file (`core.md`, `STATUS.md`, `adr/*.md`, `research/*.md`, `reports/*.md`,
area-level `index.md`) across all registered brain repos.

## Context

`project-brain` (`ai-agents/skills/project-brain/SKILL.md`) already independently arrived
at a shape structurally similar to Google's Open Knowledge Format (OKF v0.2, June 2026):
a directory of Markdown files, `index.md`/`log.md` as reserved-role filenames, and
`core.md`/`STATUS.md` already carrying a `type:` frontmatter field. OKF formalizes this
pattern into a documented, vendor-neutral spec — adopting it where it fits trades a
bespoke schema for one other tools can also read/write, at no runtime/SDK/service cost
(OKF is "a format, not a platform").

Filed as #195. The real gaps against OKF conformance turned out wider than the issue
originally scoped: `templates/adr.md` had no frontmatter at all (the one gap the issue
named), but `core.md`'s "Map" section and the area-level `index.md` also use
Obsidian-style `[[wikilink]]` syntax throughout — not OKF's markdown-link form
(`[text](/path)` absolute-bundle-relative, or `[text](./path)` relative) — a gap the issue
didn't call out.

The live decision was how much of OKF to adopt: minimal conformance only (a `type:` field
on every file) versus also adopting the optional provenance/lifecycle/versioning fields
(`generated`, `verified`, `status`, `stale_after`, bundle-root `okf_version`).

## Decision

Adopt OKF beyond minimal conformance, with type-specific choices below. Two registered
brain repos are migrated in the same pass: `E:\Personal Projects\brain\` and
`E:\HollardInsuranceRetail\brain\`. `session-start.ps1` needs no change — confirmed it
reads `core.md`/`STATUS.md` as raw whole-file text, never parses frontmatter fields, so
this migration is additive-only.

- **`type:` values**: `core`, `status`, `adr`, `research`, `report` — one non-reserved
  concept type per existing directory role. `index.md`/`log.md` stay reserved (no `type:`).
  Extended during ticket breakdown once the Hollard brain's real shape was inventoried:
  `ticket` (its per-initiative `tickets/` directories, a role not previously documented
  in `SKILL.md`), `spike` (`spikes/`, a role `SKILL.md` already named but never assigned
  a `type:`), `learner` (area-level `learner.md`, the `/walkthrough` skill's learner
  profile), and `kanban` (one ad hoc `kanban.md` found in a single initiative) — extended
  rather than left on the old schema, consistent with the `tickets/` precedent.
- **ADR frontmatter absorbs the whole bullet-list header** (`Status`/`Date`/`Scope`/
  `Supersedes`), not just `type:` — `date`, `scope`, `supersedes`, `superseded_by` all
  become YAML fields, matching how `core.md`/`STATUS.md` already put metadata in
  frontmatter rather than the body.
- **ADR status remaps to OKF's `status: draft | stable | deprecated` enum** rather than
  keeping the existing `Proposed | Accepted | Superseded by ADR-XXXX` vocabulary as a
  custom field: `Proposed → draft`, `Accepted → stable`, `Superseded → deprecated`.
  `Proposed`/`draft` has no live usage today (both existing ADRs are `Accepted`), but the
  mapping is kept for when a proposal stage is used. Supersession detail (which ADR)
  lives in `supersedes`/`superseded_by`, not folded into `status`.
- **`research/*.md` and `reports/*.md` get their own `type:` frontmatter**, not just an
  entry in their directory's `index.md` — every non-reserved file is independently
  conformant, not only the ones an index links to.
- **`stale_after` is added alongside `updated:`** on `STATUS.md`, computed at edit time
  (`updated:` + 7 days) — makes staleness machine-checkable without dropping the existing
  "if `updated:` is >7 days old, distrust this" convention.
- **`generated: { by, at }` is added to every conformant type** (`core`, `status`, `adr`,
  `research`, `report`) — mechanical, written once at file creation, no ambiguity about
  when to write it. **Backfilled onto ~266 pre-existing files, `at` is never stamped with
  today's migration date** — that would record the migration event, not original
  authorship, the opposite of what the field means. The shared conversion script (below)
  derives `at` from `git log --diff-filter=A --format=%aI -- <file>` where git history has
  it, and omits the field entirely where it doesn't; OKF tolerates missing optional
  fields, so an omitted `generated:` stays conformant. `by` is never derived or backfilled
  on a pre-existing file — there is no reliable record of which agent/session originally
  authored it, so a backfilled file may carry `generated: { at }` only, and that is
  conformant, not a gap.
- **`verified:` is never backfilled** — every migrated file gets `verified: []`
  regardless of what its prose claims. An agent reading someone else's "verified by
  spike" text and writing a `verified:` entry for it would be attesting to a
  re-confirmation the migrating agent never performed. The field is populated only
  going forward, when a later session genuinely re-confirms a research finding
  (spike/primary-source) or re-reads and re-confirms an ADR.
- **The mechanical parts (wikilink rewrite, `type:`/`stale_after:` insertion, provenance
  derivation) are done by one shared conversion script**, authored and reviewed once
  under the schema ticket, rather than freehand per migration batch — guarantees
  identical link-syntax and frontmatter formatting across ~266 files instead of drifting
  across however many agents touch them.
- **`verified: [{ by, at, ... }]` is added only to `adr` and `research`**, with a defined
  trigger so the field gets populated rather than sitting empty: on `research/*.md`, when
  a finding is confirmed by spike/primary-source rather than literature review alone
  (already an informal distinction in `research/index.md` prose, e.g. "verified by spike,
  not just researched" — now migrated into frontmatter); on `adr/*.md`, when a later
  session re-reads an ADR and confirms it still holds.
- **The whole brain repo is one OKF bundle** — only the brain-root `index.md` declares
  `okf_version: "0.2"`. Per-initiative directories (`initiatives/<id>/`) are not separate
  bundles and get no `index.md` of their own; `core.md`/`STATUS.md` stay the entry points.
- **`[[wikilink]]` syntax migrates to OKF's markdown-link form** across `core.md`'s Map
  section, `index.md`, and ADR cross-references — folded into #195 rather than split into
  a separate issue, since it's a genuine cross-link conformance gap.

## Execution notes (ticket breakdown)

Discovered only once the tickets were being dispatched, not during the grilling session:

- **`jinyeow/dotfiles` is a public repo.** The Hollard migration tickets (#198-204)
  originally named real PBI numbers and person-identifying initiative folders
  (`793186-thilina-access`, `801442-801443-hngo-sdb-access`, etc.) in their public titles
  and bodies. Redacted to generic labels (Initiative A, B, C, ...) with the real
  local-path mapping kept out of the public tracker.
- **The Hollard brain repo has a single working tree, no worktree fleet** — its 7
  migration batches (#198-204) cannot run as parallel subagents each committing
  independently (git `index.lock` collision, interleaved staged changes). They run
  sequentially, one commit per batch. Only #197 (a separate repo, the personal brain) is
  genuinely parallel with the Hollard batches.
- **`review-fix-loop` has no target in the brain repos** — `project-brain`'s own update
  contract commits straight to `main`, no branch/PR flow. Cross-model review
  (`--reviewers fable,sol --codex`) is scoped to #196's dotfiles-repo PR
  (`SKILL.md` + templates + the shared conversion script); the brain-repo migrations
  (#197-204) are verified by re-running the script's own checks plus a final
  `grep -r '\[\['` sweep for leftover wikilinks, not by review-fix-loop.

## Alternatives considered

- **Minimal conformance only** (`type:` on every file, fix `templates/adr.md`, stop
  there) — rejected. The optional fields (`status`, `stale_after`, provenance) each had a
  concrete use once examined against this brain's actual update contract, and the
  wikilink gap needed fixing regardless of how much of the optional spec was adopted.
- **Keep ADR's own `Proposed | Accepted | Superseded` vocabulary as a custom field**
  instead of remapping to OKF's `status` enum — rejected. Direct remap keeps one `status`
  vocabulary across the whole brain rather than a `type`-specific one, and supersession
  detail needs its own field either way.
- **Per-initiative OKF bundles** (an `index.md` with `okf_version` inside each
  `initiatives/<id>/`) — rejected. Initiatives aren't shared or exported independently
  today; one bundle-root declaration is sufficient and avoids adding files with no
  present consumer.
- **Skip `generated`/`verified` entirely** (single-author brain, no per-file authorship
  distinction needed) — rejected for `verified` once a real trigger was identified
  (research spike-vs-literature, ADR re-confirmation); `generated` was accepted outright
  since it's mechanical with no ambiguity.
- **Backfill only the dotfiles-repo templates now, leave the live brain repos on the old
  schema until a follow-up session** — rejected. Doing both brain repos in the same pass
  avoids leaving two brains on different schemas indefinitely.
