# Skill ownership

Ownership is explicit by source directory. Skills are portable by default; Claude-only
skills are reserved for instructions that directly require Claude Code hooks, MCP tools,
Claude-specific state, or Claude's built-in orchestration/tool surface.

## Shared (`ai-agents/shared/skills/`)

The shared directory is the default home for runtime-neutral Agent Skills. It is projected
to Claude Code, Codex CLI, and Pi where each runtime is configured to load it. This includes
`council`, `council-code`, `council-business`, `council-plan`, and `council-doc`: a shared,
cost-bounded prompt orchestration contract whose runtime adapters use native isolation.

## Claude-only (`ai-agents/claude/skills/`)

- `_shared` — support resources for Claude-oriented review skills
- `azure-boards-organiser` — Claude-specific Azure DevOps MCP tool names and config path
- `codex-review` — Claude → Codex MCP invocation
- `deep-review` — Claude-oriented review orchestration and shared review resources
- `fastmail` — Claude-specific Fastmail MCP tool names
- `fix-findings` — consumes Claude-oriented review artifacts
- `git-guardrails-claude-code` — Claude Code hook/settings installation
- `handoff` — Claude SessionStart handoff convention and `.claude` state
- `project-brain` — Claude SessionStart hook integration and Claude global state
- `review-fix-loop` — consumes Claude-oriented review artifacts
- `router` — Claude built-in skills and slash-command routing
- `storm-research` — Claude built-in `Agent`/`Write` workflow
- `walkthrough` — Claude-specific learner and project-brain state

Claude-only skills are still installed into Claude's `~/.claude/skills/`, but are not
projected to Codex or Pi as shared skills.

## Codex-specific (`ai-agents/codex/skills/`)

Codex-native variants live here only when they must differ from a shared skill and win
name collisions during projection. The directory is currently empty.

## Agents

Agent definitions under `ai-agents/shared/agents/` currently use Claude Code's flat
agent-file adapter and are projected only to `~/.claude/agents/`; the directory name means
shared repository ownership, not cross-runtime projection. Codex has no separate top-level
agent directory, and Pi packages/extensions provide isolation. Portable role contracts,
such as council critic/chair roles, belong inside their shared skill rather than here.
