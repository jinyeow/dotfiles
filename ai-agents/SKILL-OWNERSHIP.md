# Skill ownership

Ownership is explicit by source directory. Skills are portable by default; Claude-only
skills are reserved for instructions that directly require Claude Code hooks, MCP tools,
Claude-specific state, or Claude's built-in orchestration/tool surface.

## Shared (`ai-agents/shared/skills/`)

The shared directory is the default home for runtime-neutral Agent Skills. It is projected
to Claude Code, Codex CLI, and Pi where each runtime is configured to load it.

## Claude-only (`ai-agents/claude/skills/`)

- `_shared` — support resources for Claude-oriented review skills
- `azure-boards-organiser` — Claude-specific Azure DevOps MCP tool names and config path
- `codex-review` — Claude → Codex MCP invocation
- `council` — Claude agent orchestration and optional Codex MCP seat
- `council-business`
- `council-code`
- `council-doc`
- `council-plan`
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

## Agents

Agent definitions live under `ai-agents/shared/agents/` as the source-of-truth location.
They currently use Claude Code's flat agent-file format and are projected to
`~/.claude/agents/`. Codex has no separate top-level agent directory; a Codex-specific
agent belongs under a skill's `agents/openai.yaml`. Pi has no built-in custom-agent
filesystem convention; Pi extensions/packages or skills provide that integration.
