# AI agent resources

This directory owns portable agent resources. Runtime-native skills live in their runtime
modules, and ownership is expressed by the directory rather than inferred from skill prose:

- `skills/` — portable (agent-agnostic) skills projected to supported runtimes, including
  `skills/_shared/` — the projected review-support contract (`dimensions.md`,
  `findings-schema.md`, `review-rubric.md`, `reviewer-models.md`) shared by `quick-review`,
  `deep-review`, `review-fix-loop`, and `fix-findings`, all four of which are portable skills
  under `skills/` too.
- `_shared/` — a separate, source-only portable review-support copy; not a standalone skill and
  not projected. Independently owned from `skills/_shared/` and may diverge — do not confuse
  the two: `skills/_shared/` is live and reachable by installed skills, this one is not.
- `agents/` — the source of truth for current user-scope agent definitions, projected to
  Claude Code.

Claude-native skills and projected support content live in `../claude/skills/`; Codex-native
variants belong in `../codex/skills/`; Pi-native variants remain in `../pi/skills/`.

Codex has no separate top-level agent directory; Codex-specific agent metadata belongs in a
skill's `agents/openai.yaml`. The review skills' per-dimension `multi_agent` custom agents
(a different mechanism — `spawn_agent` role definitions, not skill-level identity) are
declared as `[agents.<name>]` tables in `codex/config.toml` instead; see
`ai-agents/skills/deep-review/DISPATCH.md`. Pi has no built-in custom-agent directory; use a
Pi package or extension when a custom agent needs runtime integration.

Installer projections consume these current source areas. The released historical roots
`ai-agents/shared/skills/`, `ai-agents/claude/skills/`, and `ai-agents/codex/skills/` remain
compatibility identifiers for safe upgrade ownership detection only; installers never recreate
them.
