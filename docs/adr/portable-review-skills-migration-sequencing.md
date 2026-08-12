# Portable review-skill migration: relocate `_shared/` with the first ticket, Pi before Codex

## Context

#101 splits `deep-review` into a lighter default (`quick-review`) plus an opt-in full
7-dimension `deep-review`, both still Claude-native. #93's research confirmed both Codex
CLI and Pi have a primitive equivalent to Claude's `Agent` tool — parallel subagent
dispatch with per-agent tool scoping — unblocking a migration of `quick-review` /
`deep-review` / `review-fix-loop` / `fix-findings` out of `claude/skills/` into
`ai-agents/skills/`, alongside `council`. The shared review contract
(`_shared/dimensions.md`, `_shared/findings-schema.md`, `_shared/review-rubric.md`)
currently lives only under `claude/skills/_shared/` and is referenced by relative path
(`claude/skills/deep-review/SKILL.md:12-14`) — any runtime other than Claude needs it
relocated first.

## Decision

Two tickets, one per target runtime, both blocked-by #101:

- **Ticket 1 (Pi)**: migrates all four skills to `ai-agents/skills/`, relocates `_shared/`
  to `ai-agents/skills/_shared/`, and designs Pi's per-seat scoping via its `tools:`
  frontmatter allowlist.
- **Ticket 2 (Codex)**: blocked-by ticket 1 (needs the relocated `_shared/` to exist).
  Ports the same skills to Codex, designs the coarser `sandbox_mode`/`mcp_servers`
  scoping mapping, and reviews the relocated `_shared/` for genuine cross-runtime
  compatibility rather than accidental Pi-only fit.

Pi goes first: its `tools:` allowlist is the same grain as Claude's existing per-tool
restrictions, making it the lower-risk runtime to prove out the new `_shared/` location
and the general portable-review-skill shape. Codex's coarser sandbox/MCP-server scoping
is real design work, better done second against an already-proven `_shared/`, and Codex
separately carries an unconfirmed minimum-CLI-version/invocation-syntax risk
(`codex/README.md:83`) that would otherwise compound with the `_shared/` relocation.

## Rejected alternatives

### One combined ticket for both runtimes

The two runtimes need genuinely different scoping vocabulary and different smoke tests;
bundling them means one runtime's slower discovery blocks the other's merge.

### A separate prerequisite ticket just for relocating `_shared/`

Three small markdown files don't stand on their own as ticket-sized work — the first
per-runtime ticket that touches those paths anyway can carry the relocation without
adding a review handoff.
