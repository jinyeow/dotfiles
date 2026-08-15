# Relocate shared `AGENTS.md` from `claude/` to `ai-agents/`

## Status

Accepted. Governs the source location of the shared coding-conventions file and every
projection that installs it (`setup.ps1`, `setup.sh`).

## Context

`claude/AGENTS.md` was the single shared coding-conventions source for Claude Code and
Codex CLI: `~/.claude/CLAUDE.md` imported it via `@AGENTS.md`, and the `codex` module
copied the same source to `~/.codex/AGENTS.md`. Its content is agent-agnostic — it is
explicitly the file that defines the "default to agent-agnostic placement" rule (added
by #135) — but its home was a Claude-specific directory, a historical artifact of when
Claude Code was the only runtime this repo supported. That placement contradicted the
rule the file itself states.

`claude/AGENTS.d/` held the satellite files (`git-worktrees.md`, `project-brain.md`)
that `AGENTS.md` links out to on demand, using relative Markdown links
(`AGENTS.d/git-worktrees.md`). Moving `AGENTS.md` alone would have broken those links in
the source tree, so `AGENTS.d/` moves with it.

## Decision

Move `claude/AGENTS.md` and `claude/AGENTS.d/` to `ai-agents/AGENTS.md` and
`ai-agents/AGENTS.d/`, keeping the two as siblings so the file's own relative links stay
valid. Every reference is repointed at the new source path; the installed destinations
(`~/.claude/AGENTS.md`, `~/.claude/AGENTS.d/`, `~/.codex/AGENTS.md`,
`~/.codex/AGENTS.d/`) are unchanged, since only the repo source moved, not the projection
targets.

`claude/CLAUDE.md`'s import changes from `@AGENTS.md` to `@../ai-agents/AGENTS.md`.
Claude Code resolves `@`-imports relative to the real (symlink-resolved) directory of the
importing file, not the symlink's apparent location — confirmed by inspecting this
session's own loaded system prompt, which labels the imported content with the
underlying repo path rather than the `~/.claude/` install path. A bare `@AGENTS.md`
import would silently stop resolving once `claude/AGENTS.md` no longer exists on disk, so
the import needed an explicit relative path, not just a moved target.

Pi has no installed home-directory copy of this file; it reads the project's own root
`AGENTS.md` directly (per `ai-agents/skills/fix-findings/SKILL.md`). There was therefore
no Pi projection to repoint — Pi is unaffected by this move.

## Rejected alternatives

### Leave a compatibility shim at `claude/AGENTS.md`

A stub or symlink at the old path pointing to the new one would keep any stale external
reference working. Rejected: every reference in this repo is grep-discoverable and was
updated in the same change (this is a projection/import refactor, not a bare file move),
so a shim would only mask a real dangling reference rather than prevent one — see
`AGENTS.md` → "Fix root causes, not symptoms."

### Move only `AGENTS.md`, leave `AGENTS.d/` under `claude/`

Cheaper diff, but `AGENTS.md`'s two `AGENTS.d/...` links are relative and would resolve
to a nonexistent `ai-agents/AGENTS.d/` once the parent file moved. Rejected as leaving a
known-broken link in the moved file.
