# AI agent resources

This directory is the canonical source for skills and agent definitions shared by supported
agent runtimes, plus the small set of runtime-specific resources. Ownership is expressed by
the directory, not inferred from skill prose:

- `shared/skills/` — skills that do not require one specific runtime. They may describe
  cross-harness conventions or optional integrations, but must remain useful without a
  Claude-only hook, MCP tool, or orchestration surface.
- `shared/agents/` — the source-of-truth for the current user-scope agent definitions;
  these are currently written in Claude Code's flat agent-file format and projected to
  Claude Code.
- `ai-agents/claude/skills/` — Claude Code-only skills and Claude-coupled support resources.
- `ai-agents/codex/skills/` — reserved for Codex-specific variants.
- `pi/skills/` — reserved for Pi-specific variants.

Codex has no separate top-level agent directory; Codex-specific agent metadata belongs in a
skill's `agents/openai.yaml`. Pi has no built-in custom-agent directory; use a Pi package or
extension when a custom agent needs runtime integration.

The installer projections in the individual runtime modules consume these source areas.
Do not restore a second `claude/skills` or `codex/skills` source tree; those are installed paths, not source areas.
