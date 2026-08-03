# AI agent resources

This directory is the canonical source for skills shared by supported agent runtimes and
for runtime-specific skills. Ownership is expressed by the directory, not inferred from
skill prose:

- `shared/skills/` — portable skills. These files must not depend on Claude, Codex, or Pi
  tools, hooks, paths, or invocation conventions.
- `ai-agents/claude/skills/` — Claude Code-only skills and Claude-coupled support resources.
- `ai-agents/codex/skills/` — reserved for Codex-specific variants.
- `pi/skills/` — reserved for Pi-specific variants.

The installer projections in the individual runtime modules consume these source areas.
Do not restore a second `claude/skills` or `codex/skills` source tree.
