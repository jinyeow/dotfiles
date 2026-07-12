---
name: project-brain
description: >
  Load and maintain the "project brain" - durable cross-repo initiative knowledge (core context,
  volatile STATUS, ADRs, research, reports) that lives in a git repo OUTSIDE any single code repo, so
  work spanning multiple repos/worktrees/spikes stays coherent between sessions. Use when resuming or
  continuing a multi-directory initiative, scaffolding a new initiative or a new brain area, recording a
  decision as an ADR, updating status, closing out a session, or filing a research/report artifact.
---

# project-brain

A **brain** is a versioned knowledge base for one *area* (e.g. all work under
`E:\HollardInsuranceRetail\`). It holds per-initiative working knowledge and is the single source of
truth for "where are we". It is distinct from the code **wiki** (`<area>\wiki\`), which is code-derived
and regenerate-able; the brain's truth source is the work. Design rationale: `<brain>/adr/0001-project-brain.md`.

## Where things live

- Global map: `~/.claude/project-brain/brains.json` - `[{ scope, path }]`, one per area. The SessionStart
  hook (`~/.claude/skills/project-brain/scripts/session-start.ps1`) reads it.
- A brain repo per area: `index.md`, `log.md`, `registry.json`, `adr/`, `templates/`, `reports/`,
  `initiatives/<id>/`.
- An initiative: `core.md` (stable, auto-loaded), `STATUS.md` (volatile, auto-loaded), `adr/`,
  `research/` (+ `index.md`), `reports/`, `spikes/`.
- Single-directory work uses the same schema in the repo's gitignored `.claude/brain/` instead.

## Loading (how context reaches a session)

In Claude Code, the SessionStart hook auto-injects the resolved `core.md` + `STATUS.md` (on
startup/resume/compact). In any tool, follow this **resolve-and-read** procedure manually when you need it:
1. Normalize the cwd. If an ancestor has `.claude/brain/core.md`, that is the brain (self-contained).
2. Else pick the `brains.json` entry whose `scope` is the longest ancestor of cwd; read its
   `registry.json`; find the initiative whose `dirs` glob matches cwd.
3. Read that initiative's `core.md` + `STATUS.md`. Read `research/`, `adr/`, `reports/` only on demand
   (their index is in `core.md`'s map section). If `STATUS.md`'s `updated:` is >7 days old, say so before trusting it.

## Update contract

**On resume (usually automatic):** trust the injected `core.md` + `STATUS.md`; check the staleness date;
read a specific ADR/research item from the map only if the task needs it. Do not read `research/` wholesale.

**On a decision** (anything you'd not want re-litigated): write a new `adr/NNNN-slug.md` from
`templates/adr.md` (MADR-lite). Never edit an accepted ADR - supersede it. Add a one-line link under
`core.md`'s "Key decisions". Cross-cutting decisions (spanning initiatives) go in the brain's top-level `adr/`.

**On a status-relevant event** (build/run result, PR merged, gate passed/failed, blocker found/cleared):
edit `STATUS.md` now - refresh `Now` / `Blocked on` / `Next action`, bump `updated:`.

**On producing research or a report:** file research under `research/` with a one-line entry in
`research/index.md` (date, question, verdict); file HTML/other reports under `reports/` named
`YYYY-MM-DD-<slug>` with an entry in `reports/index.md`. Never leave durable outputs in tmp.

**On session close:** (1) refresh `STATUS.md`; (2) append 2-5 lines to the brain's `log.md`
(`## [date] <op> | <initiative> - <what moved>`); (3) `git -C <brain> add -A && git commit` (conventional
message); (4) delete anything this session duplicated outside the brain.

**On landing** (initiative changes a durable fact the code wiki asserts): promote that fact into
`<area>/wiki/` via a wiki ingest and log it. Volatile status never goes to the wiki. The brain may link to
wiki pages; the wiki never depends on the brain.

**Always:** no secrets in the brain (no credentials/tokens/PATs/connection strings). Identifiers (SPN/MG
names, PBI/run IDs) are fine.

## Scaffolding

**New initiative** (spans >1 working directory - worktrees/repos/spikes; single-directory work stays
in-repo under `.claude/brain/`):
1. Gather the directories it spans; compute their longest common ancestor.
2. Find the `brains.json` entry whose `scope` is an ancestor of that. **Confirm the target brain/scope
   with the user before scaffolding** (always, even when a scope matches). If none matches, run "new area".
3. Key it `<PBI-id>-<slug>` (bare slug if no PBI). Create `initiatives/<id>/` from `templates/` (`core.md`,
   `STATUS.md`, `adr/`, `research/index.md`, `reports/index.md`).
4. Add a `registry.json` entry: `"<id>": { "title", "status": "active", "dirs": ["<glob>", ...] }`, where
   each glob matches (`-like`, forward slashes) the cwd of a spanned directory.
5. Add a row to the brain's `index.md`; append to `log.md`; commit.

**New area** (a whole new brain, e.g. personal projects): propose the common ancestor as the `scope` root
and **confirm with the user**. Then `git init` `<scope>/brain/`, scaffold `index.md`/`log.md`/
`registry.json`/`templates/`/`adr/`, and append `{ scope, path }` to `brains.json`.

**Initiative close:** move `initiatives/<id>/` to `initiatives/_archive/`, remove its `registry.json`
entry, add a closing `log.md` line, commit.

## Portability

`SKILL.md` is an open standard: this same file works in Claude Code and Codex CLI (`~/.codex/skills/`),
etc. Only the auto-load SessionStart hook is Claude-Code-specific; in other tools this skill's
resolve-and-read procedure is triggered by description or an `AGENTS.md` pointer.
