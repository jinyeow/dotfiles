# AI agent resources

This directory owns portable agent resources. Runtime-native skills live in their runtime
modules, and ownership is expressed by the directory rather than inferred from skill prose:

- `skills/` — portable (agent-agnostic) skills projected to supported runtimes.
- `_shared/` — portable review-support source content; source-only, not a standalone skill.
- `shared/agents/` — the source of truth for current user-scope agent definitions (unchanged
  in this layout migration); these are projected to Claude Code.

Claude-native skills and projected support content live in `../claude/skills/`; Codex-native
variants belong in `../codex/skills/`; Pi-native variants remain in `../pi/skills/`.
The two `_shared` directories are independently owned and may diverge: Claude's
`claude/skills/_shared/` is projected with Claude skills, while `ai-agents/_shared/` remains
source-only.

Codex has no separate top-level agent directory; Codex-specific agent metadata belongs in a
skill's `agents/openai.yaml`. Pi has no built-in custom-agent directory; use a Pi package or
extension when a custom agent needs runtime integration.

Installer projections consume these current source areas. The released historical roots
`ai-agents/shared/skills/`, `ai-agents/claude/skills/`, and `ai-agents/codex/skills/` remain
compatibility identifiers for safe upgrade ownership detection only; installers never recreate
them.
