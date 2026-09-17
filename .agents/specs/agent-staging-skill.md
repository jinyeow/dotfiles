# agent-staging skill

## Problem Statement

The `staging-io` skill describes a single folder, `E:\HollardInsuranceRetail\agent-staging\`,
framed entirely as work-PC (WPC) hand-carry traffic tied to ADO tickets. In practice the
`agent-staging` idea is broader: the developer wants a plain place where they and their agents
(Claude, Codex, Pi) can drop files for each other and copy from easily, across sessions, not tied
to any ticket or the WPC. A neutral folder for this already emerged on its own at
`E:\Personal Projects\agent-staging\` (holding review and research artifacts), but the skill does
not describe it, the naming and lifecycle rules do not fit it, and the skill's authority is split
with an on-disk `README.txt` contract it claims to mirror. The two frames also collide on the
literal folder name `agent-staging`.

## Solution

Redefine `agent-staging` as a per-pseudo-root drop and exchange zone, and rename the skill from
`staging-io` to `agent-staging` to match. A pseudo-root is a workspace directory that holds repos
(for example `E:\Personal Projects\` or `E:\HollardInsuranceRetail\`); each pseudo-root has its own
`agent-staging\` folder, and the active one is the folder beside the current repo. The folder has
two lanes: `agent-inputs\` for files the developer drops for an agent, and `agent-outputs\` for
files an agent produces for the developer. Files use a short slug name and are cleaned up on an age
rule. The skill is the single source of truth. WPC hand-carry becomes a scoped sub-section of the
one skill: the specialized case that applies when a file must cross to the work PC under the work
pseudo-root.

## User Stories

1. As a developer, I want one documented place per workspace to drop files for my agents, so that I
   do not have to invent an ad-hoc location each session.
2. As a developer, I want my agents (Claude, Codex, Pi) to know where to read the files I drop, so
   that I can hand them scripts, data, and prompts without pasting everything into chat.
3. As a developer, I want my agents to write their outputs to a known place I can copy from, so that
   large or multi-file results do not have to live in the chat transcript.
4. As an agent, I want a rule that resolves the correct `agent-staging\` folder from the current
   working directory, so that I write to the folder that belongs to the workspace I am in.
5. As a developer working under my personal projects root, I want the personal `agent-staging\`
   folder used automatically, so that work and personal scratch stay separate.
6. As a developer working under my work root, I want the work `agent-staging\` folder used
   automatically, so that WPC hand-carry traffic stays where its extra rules apply.
7. As a developer, I want dropped files named by a short slug (a ticket slug, a brief descriptor, or
   the related brain initiative), so that I can tell at a glance what each file is about.
8. As a developer, I want stale files purged on an age rule, so that the folder stays a temporary
   store and does not become a filing cabinet.
9. As a developer, I want a single authority for the rules (the skill), so that an on-disk contract
   file cannot drift out of sync with the skill.
10. As a developer hand-carrying a script to the work PC, I want the strict WPC conventions
    (ticket-seq naming, out/err/retry reply pairing, the header block, and the encoding checks) to
    still apply, so that the hand-carry workflow keeps working.
11. As a developer pasting WPC output back, I want the inbound safety rules available on disk, so
    that I can follow them without an agent in the loop.
12. As a developer, I do not want live secrets sitting in the folder, so that a dropped file cannot
    leak a credential; if one lands, it is deleted and the secret rotated rather than edited in
    place.
13. As a developer, I want the folder to always live outside any git repo, so that dropped files are
    never accidentally committed.
14. As a developer, I want the renamed skill projected to Claude, Codex, and Pi and the old
    `staging-io` links removed, so that only the new skill is discoverable.

## Implementation Decisions

- **Rename the skill** from `staging-io` to `agent-staging`: rename the source directory under
  `ai-agents/skills/`, update the frontmatter `name`, and rewrite the `description` so it triggers on
  the general per-root drop/exchange use, not WPC-only. Bump the frontmatter `version` (major, since
  the purpose and contract change).
- **Single deep module.** The skill file is the one module and the single source of truth. Its
  interface is what an agent reads to learn the folder convention and rules. No on-disk `README.txt`
  is mirrored; where a folder benefits from being self-documenting, a short pointer file names the
  skill instead of restating the contract.
- **Folder resolution rule.** `agent-staging\` sits at the pseudo-root, defined as the parent of the
  current repo's top-level directory (for example, working in `E:\Personal Projects\dotfiles\main`
  resolves the repo root `E:\Personal Projects\dotfiles\` and the pseudo-root
  `E:\Personal Projects\`, so `E:\Personal Projects\agent-staging\` is used). The skill names the two
  current roots (`E:\Personal Projects\`, `E:\HollardInsuranceRetail\`) as concrete examples. The
  folder is created on first use and is always outside any git repo.
- **Lanes.** `agent-inputs\` is developer-to-agent, `agent-outputs\` is agent-to-developer. Both
  pseudo-root folders use the same lane structure.
- **General naming.** A short slug: a ticket slug when ticket-related, otherwise a brief descriptor
  of the work or the related brain initiative.
- **Lifecycle.** Temporary store, manual age purge at roughly 7 to 14 days, no daemon or sync.
- **WPC sub-section.** The existing strict apparatus is kept but scoped to "when a file crosses to
  the work PC": ticket-`seq` naming, `out`/`err`/`retryNN` reply pairing, the four-field header
  block, the encoding and parse checks, and close-out on the ADO PBI reaching Done. This apparatus
  applies to the work-root folder only.
- **Secret hygiene.** Do not drop live secrets into any lane; if one lands, delete the file and
  rotate the secret rather than editing it out and keeping the file. The stricter WPC specifics
  (never paste access-token output, `--debug` output, or unfiltered Key Vault secret values) stay in
  the WPC sub-section.
- **On-disk files in the work-root folder.** `INBOUND-SAFETY.txt` is kept on disk, because a human
  reads it at paste-time with no agent in the loop. The work-root `README.txt` is reduced to a
  pointer to the skill, retaining only the human-facing "before you run on the WPC" encoding and
  parse steps; the rest of its contract moves into the skill.
- **Live-folder setup (outside version control).** Add `agent-inputs\` and `agent-outputs\` lanes to
  `E:\Personal Projects\agent-staging\` and move its current flat files into `agent-outputs\`. Delete
  the empty `SCRATCH.md`. These are real files with no PR to revert them, so the exact moves and
  deletes are shown before they run.
- **Projection.** Run `setup.ps1 -Module ai-agents` from the C: clone to project the renamed skill
  into `~/.claude`, `~/.codex`, and `~/.pi`, and explicitly remove the now-orphaned `staging-io`
  junctions from those three runtime skill directories, which the rename does not clean up on its
  own.
- **No ADR.** The developer declined an ADR for this reversal of the earlier "skill mirrors the
  README contract" model.

## Testing Decisions

- Skill content is prose with no unit-test harness in this repo, so testing is limited to the
  observable, external outcomes rather than the file's internal wording.
- CI gates on the change: `gitleaks` (no secrets in the skill), markdown and shell/style checks, and
  the existing Pester and `setup.sh` suites must stay green. The change is docs and a directory
  rename, so no existing test should need editing; if one references the `staging-io` path, update it
  to `agent-staging`.
- Manual verification after projection: the `agent-staging` skill appears in `~/.claude/skills`,
  `~/.codex/skills`, and `~/.pi/agent/skills`, each junction points at the C: repo copy, and no
  `staging-io` junction remains in any of the three.
- Manual verification of the folder-resolution rule against both pseudo-roots: from a repo under
  `E:\Personal Projects\` the rule resolves `E:\Personal Projects\agent-staging\`, and from a repo
  under `E:\HollardInsuranceRetail\` it resolves the work folder.
- Prior art: this repo's existing skills carry no behavioral tests, so there is no test module to
  mirror; the bar is CI-green plus the manual checks above.

## Out of Scope

- Any wrapper script, CLI, module, daemon, or sync for the folder; it stays a plain folder.
- Changing `setup.ps1`'s skill-projection logic; the rename is picked up by its existing directory
  discovery, and only orphan-junction cleanup is added as a manual step.
- An ADR (declined).
- Migrating or reorganizing the work-root folder's existing ticket artifacts beyond the
  `README.txt` pointer swap and the `SCRATCH.md` deletion.
- Automating the age-based purge; it stays manual.

## Further Notes

- Two folders keep the name `agent-staging` by design (one per pseudo-root); the active one is
  chosen by the current working root, so the shared name is not a collision within a given context.
- The work-root `agent-staging` folder is barely exercised today (one real hand-carry file, empty
  archive), while the personal-root folder is already in active use for agent research and review
  outputs. The redesign follows that real usage.
- The skill is model-invoked (it auto-fires on its description), so the rewritten `description` is
  load-bearing for discovery and must clearly cover the general drop/exchange use while still
  matching the WPC case.
