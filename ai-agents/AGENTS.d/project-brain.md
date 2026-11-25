# Project brain

Durable cross-repo initiative knowledge (per-initiative `core.md` plus volatile `STATUS.md`, and ADRs/research) lives in a git "brain" repo outside any code repo. Claude Code auto-loads it via a SessionStart hook; Codex has no such hook, so resolve-and-read it manually whenever the session cwd sits in a tracked initiative:
1. If an ancestor of cwd has `.claude/brain/core.md`, that is the brain (self-contained) — in that case, still check the registry for a second, registered initiative matching this cwd and say so if found, since the in-repo brain wins by design but can shadow one. Otherwise read `~/.claude/project-brain/brains.json` and pick the entry whose `scope` is the longest ancestor of cwd.
2. Read that brain's `registry.json`, find the initiative whose `dirs` glob matches cwd, and read its `core.md` and `STATUS.md` (read `research/`, `adr/`, `reports/` only on demand).
3. If `STATUS.md`'s `updated:` is more than 7 days old, flag that before trusting it.

A workspace is a `brains.json` scope plus its brain. A workspace can also have an optional Home Repo (`gateroom`), which holds the brain in its `brain/` folder. In a workspace with a Home Repo, every work item is an initiative, including a single-repo item, and in-repo `.claude/brain/` is only for a repo outside the workspace. Without a Home Repo, single-directory work stays in-repo under `.claude/brain/`. Never keep durable state in gitignored worktree scratch.

Start the first session of an initiative at the brain root, or at the Home Repo root when there is one. Start later sessions in the initiative's folder (`<brain>/initiatives/<id>`), or in a worktree of one of its work items. Both match a registry glob, so the initiative loads. A session at the brain root or the Home Repo root loads none. Each work item has its own branch (`<type>/<item>-<slug>`) and worktree per repo, and the worktree folder name replaces `/` with `-`. Create every worktree with `git worktree add`, in normal clones too, so the work-item glob matches.

The full contract (record decisions as ADRs, file research/reports, refresh STATUS, append the session narrative to the initiative's `log.md`, then append to the brain's root log on session close) is in `~/.claude/skills/project-brain/SKILL.md`.
