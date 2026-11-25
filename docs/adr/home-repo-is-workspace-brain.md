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

A workspace is one `brains.json` scope plus its brain. The brain can be its own git repo, for
example `<scope>/brain/`. The `project-brain` skill works with that alone.

A workspace can opt in to one Home Repo named `gateroom`, directly inside the scope folder. The
Home Repo is optional. The rules below apply only to a workspace that has one. The layout is:

- `AGENTS.md`: intro, Work tracking, Other Repos pointers, a rule against `.claude/handoff.md`,
  and a line saying global rules and skills load from the runtime folders. `CLAUDE.md` is a
  one-line pointer to it.
- `repos/<area>.md`: pointer files, once a workspace passes about 20 repos.
- `wiki/`: long-term knowledge, standards and conventions, with a hand-written rules section
  that ingests never overwrite.
- `skills/`: workspace-only, ad hoc skills.
- `brain/`: the OKF bundle, and the path `brains.json` points at. The schema is unchanged, and
  each initiative gains a `specs/` folder.

In a workspace with a Home Repo, every work item is an initiative, including a single-repo item.
In-repo `.claude/brain/` stays only for a repo outside that workspace. In a workspace without a
Home Repo, an initiative spans more than one directory, and single-directory work stays in-repo
under `.claude/brain/`. In every workspace, durable state never goes in gitignored scratch inside
a worktree, because removing the worktree deletes it.

The Home Repo is opt-in because the `project-brain` skill must work on its own. The skill also
ships as a standalone plugin, and a machine with only that plugin has no `setup-home-repo` skill.

The workspace default tracker goes in the Home Repo's `AGENTS.md` under Work tracking. A repo
with a different tracker gets a hint on its pointer line that points at the repo's own workflow
config.

The Home Repo refers to global rules and skills by their runtime folders (Claude, Codex, shared
agent skills, Pi). It does not use a path into the source repo that installs them. A machine can
get the same rules and skills from the installer, from the standalone `project-brain` plugin, or
by hand. The runtime folder path is the same on every machine. A source path exists only on a
machine that has that source repo at that path, so an instruction that uses it breaks elsewhere.
The Home Repo can still list the source repo as a workspace repo, and the brain can hold an
initiative about it. Those are project content and break nothing on another machine.

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
