# Make the Home Repo the workspace brain

## Status

Accepted.

## Context

Work state sits in four places that overlap: a per-item notes folder in the work Home Repo, the
project brain, `.claude/handoff.md`, and "What's next" comments on the tracker. A new session
has no single place that shows where an initiative stands. The wiki, the brain and the
repo pointers each live in a different repo or folder.

Measured on 2026-11-24: the work wiki has 24 commits (2026-07-14 to 2026-09-17). The work
brain has 616 commits since 2026-07-11. The brain drives history volume. The wiki changes
slowly.

## Decision

Each workspace gets one Home Repo named `gateroom`, directly inside the scope folder. A workspace is one
`brains.json` scope plus its Home Repo. The layout is:

- `AGENTS.md`: intro, Work tracking, Other Repos pointers, a rule against `.claude/handoff.md`,
  and a line saying global rules and skills load from the runtime folders. `CLAUDE.md` is a
  one-line pointer to it.
- `repos/<area>.md`: pointer files, once a workspace passes about 20 repos.
- `wiki/`: long-term knowledge, standards and conventions, with a hand-written rules section
  that ingests never overwrite.
- `skills/`: workspace-only, ad hoc skills.
- `brain/`: the OKF bundle, and the path `brains.json` points at. The schema is unchanged, and
  each initiative gains a `specs/` folder.

Every work item in a workspace is an initiative, including a single-repo item. In-repo
`.claude/brain/` stays only for a repo outside any workspace. Durable state never goes in
gitignored scratch inside a worktree, because removing the worktree deletes it.

The workspace default tracker goes in the Home Repo's `AGENTS.md` under Work tracking. A repo
with a different tracker gets a hint on its pointer line that points at the repo's own workflow
config.

The Home Repo never names the repo that installs the global rules and skills. It names the
runtime folders (Claude, Codex, shared agent skills, Pi) when it refers to global material.

`STATUS.md` is the source of truth for status. The tracker only receives team updates.

## Alternatives considered

- **A separate wiki repo.** The wiki has few commits next to the brain, so a separate repo
  protects no history. A separate repo also splits the pointers, wiki and brain across three
  places. Rejected. An existing wiki moves in with `git subtree add`, history kept, and
  `git subtree split` reverses it.
- **The brain at the Home Repo root.** The root already holds `AGENTS.md`, `repos/`, `wiki/` and
  `skills/`. The OKF bundle root needs its own `index.md` with `okf_version`. A `brain/` folder
  keeps the bundle boundary and the `brains.json` path unambiguous. Rejected.
- **Keeping the per-item `work/` notes folder.** It overlaps the brain and needs its own
  handover. One initiative per work item replaces it. Rejected.
- **The tracker as the status store.** Tracker comments need user approval to post, closing an
  item is a user action, and trackers differ per repo. A tracker cannot be the one source of
  truth for an agent session. Rejected. The tracker gets team updates only.
