---
name: project-brain
description: >
  Load and maintain the "project brain" - durable cross-repo initiative knowledge (core context,
  volatile STATUS, ADRs, research, reports) that lives in a git repo OUTSIDE any single code repo, so
  work spanning multiple repos/worktrees/spikes stays coherent between sessions. Use when resuming or
  continuing a multi-directory initiative, scaffolding a new initiative or a new workspace, recording a
  decision as an ADR, updating status, closing out a session, or filing a research/report artifact.
---

# project-brain

A **workspace** is one `brains.json` scope (for example all work under `~/work/`) plus its **Home
Repo**. The Home Repo is named `gateroom` and is a git repo directly inside the scope folder (`<scope>/gateroom/`). A **brain** is the
versioned knowledge base in the Home Repo's `brain/` folder. It holds per-initiative working
knowledge and is the single source of truth for "where are we". It is distinct from the workspace
**wiki** (`wiki/` in the Home Repo), which holds long-term knowledge. The
brain's truth source is the work.

The word "area" has one meaning left: a group of repos in a `repos/<area>.md` pointer file.

Decision record: `docs/adr/home-repo-is-workspace-brain.md` in the dotfiles repo.

## Home Repo layout

```
gateroom/
  AGENTS.md    intro, Work tracking, Other Repos pointers, a rule against .claude/handoff.md,
               and a line saying global rules and skills load from the runtime folders
  CLAUDE.md    one-line pointer to AGENTS.md
  repos/       <area>.md pointer files, once the workspace passes about 20 repos
  wiki/        long-term knowledge, standards and conventions, plus a hand-written rules section
  skills/      workspace-only, ad hoc skills
  brain/       the brain: the OKF bundle that `brains.json` points at
```

- Work tracking: the workspace default tracker goes in `AGENTS.md`, under a Work tracking
  heading. A repo that uses another tracker gets a hint on its pointer line in `AGENTS.md`. The
  hint points at the repo's own workflow config. Tracker details live in that config only.
- Wiki: ingests never overwrite the hand-written rules section.
- Every work item in a workspace is an initiative, including a single-repo item. There is no
  per-item notes folder.
- In-repo `.claude/brain/` is only for a repo outside any workspace.
- Durable state never goes in gitignored scratch inside a worktree. Removing the worktree
  deletes that scratch. Put the state in the brain.
- The Home Repo never names the repo that installs the global rules and skills. It names the
  runtime folders (Claude, Codex, shared agent skills, Pi) when it refers to global material.

## Where things live

- Global map: `~/.claude/project-brain/brains.json` - `[{ scope, path }]`, one per workspace. The SessionStart
  hook (`scripts/session-start.ps1` in this skill directory, whether installed by the dotfiles setup or
  as the Claude Code plugin) reads it.
- A brain per workspace (the Home Repo's `brain/` folder): `index.md`, `log.md`, `registry.json`,
  `adr/`, `templates/`, `reports/`, `initiatives/<id>/`, and optionally `learner.md`, the
  `/walkthrough` skill's workspace-level learner profile (domain knowledge the user has
  demonstrated; written by walkthrough close-out, read to pitch tour depth). It sits at workspace
  level because the user's knowledge spans initiatives.
- An initiative: `core.md` (stable, auto-loaded), `STATUS.md` (volatile, auto-loaded),
  `log.md` (session history for this initiative, read on demand, not auto-loaded), `adr/`,
  `research/` (+ `index.md`), `reports/`, `spikes/`, `specs/`, and, per initiative role, `tickets/`
  (per-PBI ticket files) or a one-off `kanban.md`.
- A repo outside any workspace uses the same schema in its gitignored `.claude/brain/` instead.

## Schema: the Open Knowledge Format

Every brain file conforms to Google's Open Knowledge Format (OKF v0.2, June 2026) — a directory of
Markdown files with YAML frontmatter and standard markdown links, not a bespoke schema. Full
rationale: `docs/adr/adopt-okf-for-project-brain-markdown.md` in the dotfiles repo.

**Bundle root:** only the brain-root `index.md` declares `okf_version: "0.2"` in its frontmatter.
Per-initiative directories are not separate bundles and get no `index.md` of their own.

**`type:` enum** — one non-reserved concept type per directory role. `index.md` and `log.md` are
reserved role filenames and carry no `type:`. A per-initiative `log.md` is the same reserved-role
filename as the brain-root `log.md` and carries no `type:` either.

| `type:` | File(s) |
|---|---|
| `core` | `core.md` |
| `status` | `STATUS.md` |
| `adr` | `adr/*.md` |
| `research` | `research/*.md` |
| `report` | `reports/*.md` |
| `ticket` | `tickets/*.md` (per-initiative ticket files) |
| `spike` | `spikes/*.md` |
| `learner` | `learner.md` |
| `kanban` | `kanban.md` (ad hoc, one-off) |

**Frontmatter shape per type:**

- `core.md`: `initiative`, `type: core`, `updated`, `generated: { by, at }` (written once at file
  creation — see `templates/core.md`).
- `STATUS.md`: `initiative`, `type: status`, `updated`, `stale_after` (`updated:` + 7 days,
  recomputed on every edit), `generated: { by, at }`.
- `adr/*.md`: the full former bullet-list header lives in frontmatter, not the body —
  `status: draft | stable | deprecated` (remapped from `Proposed | Accepted | Superseded`), `date`,
  `scope`, `supersedes`, `superseded_by`, `type: adr`, `generated: { by, at }`, `verified: []`.
- `research/*.md`: `type: research`, `generated: { by, at }`, `verified: []` — populated only when a
  later session confirms a finding by spike/primary-source, not literature review alone.
- `reports/*.md`: `type: report`, `generated: { by, at }`. No `verified:` — reports are point-in-time
  outputs, not standing claims to re-confirm.
- `ticket`/`spike`/`learner`/`kanban`: `type:` only — minimal conformance, no provenance/lifecycle
  fields required.

`generated.by`/`generated.at` are written once, by hand, at file-creation time for new files (the
placeholder in each template). They are never backfilled with today's date on a pre-existing file —
see the conversion script below. A backfilled (pre-existing) file may therefore carry
`generated: { at }` only, with `by` omitted rather than guessed, when the original authoring
agent/session can't be reliably attributed — this is conformant, not a gap to flag. `verified:` is
never backfilled with real entries either: every
migrated file gets `verified: []` regardless of what its prose claims; it is populated only going
forward, by a session that actually re-performs the confirmation.

**Link syntax:** Obsidian-style `[[wikilink]]` is retired in favor of OKF's standard markdown links —
`[text](/path)` (absolute, bundle-root-relative) or `[text](./path)` (relative). Applies to
`core.md`'s Map section, the brain-root `index.md`, and ADR cross-references.

**Conversion script:** `scripts/convert-to-okf.ps1` in this directory does the mechanical part of
migrating a pre-existing file — wikilink rewrite, `type:`/`stale_after:` insertion, `verified: []`
insertion (adr/research only), and `generated.at` provenance derived from
`git log --diff-filter=A --follow --format=%aI` in the file's own repo (omitted, never guessed, when
git history has none). It does not rewrite an ADR's bullet-list header into frontmatter — that remap
is per-file judgement, done by hand. Run it against a file or a directory:
`./scripts/convert-to-okf.ps1 -Path <brain-repo-or-file>`.

## Loading (how context reaches a session)

In Claude Code, the SessionStart hook auto-injects the resolved `core.md` + `STATUS.md` (on
startup/resume/compact). In any tool, follow this **resolve-and-read** procedure manually when you need it:
1. Normalize the cwd. If an ancestor has `.claude/brain/core.md`, that is the brain (self-contained).
2. Else pick the `brains.json` entry whose `scope` is the longest ancestor of cwd; read its
   `registry.json`; find the initiative whose `dirs` glob matches cwd.
3. Read that initiative's `core.md` + `STATUS.md`. Read `research/`, `adr/`, `reports/` only on demand
   (their index is in `core.md`'s map section). If `STATUS.md`'s `updated:` is >7 days old, say so before trusting it.

**Fallback when no dir glob matches (cwd resolves to nothing, or the auto-load hook is silent):** don't
treat that as "no initiative exists". A follow-up PBI whose work needed no code change in a given repo
(e.g. a config re-sync, not a file edit) never gets a dedicated worktree/glob there, so a session sitting
in a repo's default worktree (`main`, `trunk`) will never auto-match even though an initiative already
covers it. This is common, not an edge case. Before running fresh discovery (a tracker/ADO/Jira search,
re-deriving context from code) on a request that names an entity — a PBI/ticket number, a named person, a
resource — or that references prior-session continuity ("last session", "we were working on", "our
troubleshooting"), grep the brain's `log.md` and `registry.json` (titles + notes) for that keyword first.
An initiative may already own it under a different key (e.g. a follow-up PBI tracked as a continuation of
an earlier one's initiative, not its own).

**Two lines the SessionStart hook may print, and what to do with each:**
- `[project-brain] N initiatives past stale_after: ...` (optionally with an `Over the size cap:`
  clause) — mention it to the user. Do not act on it unasked.
- `[project-brain] A registered initiative also matches this directory and was NOT loaded: <id> ...`
  (a shadow notice, printed when an in-repo `.claude/brain/` wins over a registered brain match) —
  read the named initiative's `core.md`/`STATUS.md` only if the current task concerns it. The
  in-repo brain still wins and stays loaded; this is by design, not a bug to fix.

## Update contract

**On resume (usually automatic):** trust the injected `core.md` + `STATUS.md`; check the staleness date;
read a specific ADR/research item from the map only if the task needs it. Do not read `research/` wholesale.
Read the initiative's `log.md` on demand only, for example when `STATUS.md` points at it or the task
needs session history.

**On session start, read the tracker:** read the comments others posted on the initiative's work
items since `STATUS.md`'s `updated:` date. Record what matters in `STATUS.md` as inputs (a dated
line under `Now`, or under `Blocked on` when it blocks work). Do not copy whole comments. If the
tracker cannot be reached, say so and go on from `STATUS.md`.

**On a decision** (anything you'd not want re-litigated): write a new `adr/NNNN-slug.md` from
`templates/adr.md` (MADR-lite). Never edit an accepted ADR - supersede it. Add a one-line link under
`core.md`'s "Key decisions". Cross-cutting decisions (spanning initiatives) go in the brain's top-level `adr/`.

**On a status-relevant event** (build/run result, PR merged, gate passed/failed, blocker found/cleared):
edit `STATUS.md` now - refresh `Now` / `Blocked on` / `Next action`, bump `updated:`. `STATUS.md` holds
the current state only; session narrative goes to the initiative `log.md` instead.

**On a tracker update** (the team-facing view of the work): `STATUS.md` stays the source of truth.
The tracker gets team updates only. Find the tracker in the initiative's `core.md` under Work
tracking, or in the workspace `AGENTS.md`. A repo that differs points at its own workflow config.
If no tracker is recorded, post nothing.
- Progress: when you commit, draft a progress comment for the work item you are committing against.
- Completion: when that item is complete, draft a summary comment for its parent item. State what
  was done, what is left, and what is next.
- Final: when nothing is left, the summary also says the parent can be closed.
- Approval: show the user every comment before you post it. Post only after the user approves.
  Closing an item is a user action. Never close an item yourself.
- Access: use the tracker's CLI or REST API. On Azure DevOps, for example,
  `az boards work-item update --id <id> --discussion "<comment>"` adds a comment.
- Refresh `STATUS.md` first, so the comment matches it.

**On producing research or a report:** file research under `research/` with a one-line entry in
`research/index.md` (date, question, verdict); file HTML/other reports under `reports/` named
`YYYY-MM-DD-<slug>` with an entry in `reports/index.md`. Never leave durable outputs in tmp.

**On session close:** (1) refresh `STATUS.md` to current state only, about 60 lines or under; move
anything that is history into the initiative `log.md`; (2) append the session narrative to
`initiatives/<id>/log.md` (a dated heading, what was done, evidence, links); (3) append 2-5 lines to
the brain's root `log.md` (`## [date] <op> | <initiative> - <what moved>`); (4) `git -C <brain> add -A -- .`
then `git -C <brain> commit` (conventional message); (5) delete anything this session duplicated outside the brain.

**On landing** (initiative changes a durable fact the workspace wiki asserts): promote that fact into
the Home Repo's `wiki/` via a wiki ingest and log it. Volatile status never goes to the wiki. The brain may link to
wiki pages; the wiki never depends on the brain.

**Always:** no secrets in the brain (no credentials/tokens/PATs/connection strings). Identifiers (SPN/MG
names, PBI/run IDs) are fine.

## Scaffolding

**New initiative** (in a workspace, every work item is an initiative, including a single-repo item.
A repo outside any workspace keeps single-directory work in-repo under `.claude/brain/`):
1. Gather the directories it spans; compute their longest common ancestor.
2. Find the `brains.json` entry whose `scope` is an ancestor of that. **Confirm the target brain/scope
   with the user before scaffolding** (always, even when a scope matches). If none matches, run "new workspace".
3. Key it `<item>-<slug>`, where `<item>` is the parent work item's id, or the standalone item's
   id (bare `<slug>` if there is no tracker item). Create `initiatives/<id>/` from `templates/`
   (`core.md`, `STATUS.md`, `log.md`, `adr/`, `research/index.md`, `reports/index.md`, `specs/`). Record
   the tracker in `core.md`, under Work tracking. Record any ordering constraint there too.
4. Add a `registry.json` entry: `"<id>": { "title", "status": "active", "dirs": ["<glob>", ...] }`.
   Globs use `-like` and forward slashes. In a workspace, register these:
   - the initiative folder: `<scope>/gateroom/brain/initiatives/<id>` and
     `<scope>/gateroom/brain/initiatives/<id>/*`;
   - one glob per work item: `<scope>/*/<type>-<item>-*`.

   A session started at the Home Repo root matches none of them and loads no initiative. Later
   sessions start in the initiative folder, or in a worktree of one of its work items.
   Each work item gets one branch and one worktree per repo it touches. The branch is
   `<type>/<item>-<slug>`. The worktree folder name replaces `/` with `-`, so it matches the
   work-item glob. Personal work with no tracker item uses `<type>/<initiative-slug>`, and its
   globs are `<scope>/*/<type>-<initiative-slug>` and `<scope>/*/<type>-<initiative-slug>/*`.
   Add each new item's globs when you create its
   first worktree.
   If a later follow-up PBI continues this same initiative under a different ID, append
   `— aka PBI <id>, <short reason>` to `title` (both here and in `index.md`'s row) rather than
   leaving the original title as the only findable string. The loading fallback above greps
   both `title` and the registry key.
5. Add a row to the brain's `index.md`; append to `log.md`; stage with `git -C <brain> add -A -- .`
   and commit.

**New workspace** (a whole new Home Repo and brain, e.g. personal projects): run the `home-repo-init`
skill. It is user-invoked, so ask the user to run it. It creates or adopts the Home Repo, scaffolds `brain/`
from this skill's `templates/`, and adds the `brains.json` entry.

**Initiative close:**

Archive trigger. Run the close steps only when all of these hold:
- the parent item is closed;
- all children are done;
- the final parent comment is posted;
- no worktrees remain. `worktree-janitor` marks each removed worktree `merged` in the Repos
  table and drops its registry glob, so a Repos table where every row is `merged` and no work-item glob
  in the registry means none remain.

A standalone item has no children. Archive a standalone item when its PR is merged and the
item is closed. The user closes items. Never close an item yourself. When the trigger holds,
offer the close and wait for the user's go-ahead.

0. **Synthesize durable knowledge into the wiki first.** Read the initiative's `log.md` and
   `adr/`. Pick the facts that stay true after the work ends: conventions, lessons, standards,
   decisions that other work will reuse. Ingest them into the Home Repo's `wiki/` and log the
   ingest. Leave the wiki's hand-written rules section as it is. Leave volatile status out.
   Do the later steps only after the ingest is committed.
1. Move `initiatives/<id>/` to `initiatives/_archive/<id>/`.
2. Remove its `registry.json` entry. If a parent initiative's entry lists this id under
   `children`, remove it there too.
3. Move (do not delete) the initiative's row from the active section of the brain's
   `index.md` into its `## Archived` section, adding the closed date. The Archived table's
   columns are `| Initiative | Title | Closed |`, with the Initiative cell a bundle-root-absolute
   link, e.g. `[<id>](/initiatives/_archive/<id>/core.md)` — the link path gains `_archive/`
   because the folder moved.
4. Fix relative paths inside the moved files that broke because the folder is now one level
   deeper: from `_archive/<id>/`, the brain root is `../../../` and the workspace wiki is
   `../../../../wiki/`. This is separate from the index-row link in step 3, which is
   root-absolute. A 2026-09-17 review found four archived files with paths broken by exactly
   this move — the path fix is not optional.
5. Add a closing `log.md` line.
6. Commit.

## Portability

`SKILL.md` is an open standard: this same file works in Claude Code and Codex CLI (`~/.codex/skills/`),
etc. Only the auto-load SessionStart hook is Claude-Code-specific; in other tools this skill's
resolve-and-read procedure is triggered by description or an `AGENTS.md` pointer.
