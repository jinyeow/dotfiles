# Project brain

Durable cross-repo initiative knowledge (per-initiative `core.md` plus volatile `STATUS.md`, and ADRs/research) lives in a git "brain" repo outside any code repo. Claude Code auto-loads it via a SessionStart hook; Codex has no such hook, so resolve-and-read it manually whenever the session cwd sits in a tracked initiative:
1. If an ancestor of cwd has `.claude/brain/core.md`, that is the brain (self-contained). Otherwise read `~/.claude/project-brain/brains.json` and pick the entry whose `scope` is the longest ancestor of cwd.
2. Read that brain's `registry.json`, find the initiative whose `dirs` glob matches cwd, and read its `core.md` and `STATUS.md` (read `research/`, `adr/`, `reports/` only on demand).
3. If `STATUS.md`'s `updated:` is more than 7 days old, flag that before trusting it.

The full contract (record decisions as ADRs, file research/reports, refresh STATUS, append to the brain log on session close) is in `~/.claude/skills/project-brain/SKILL.md`.
