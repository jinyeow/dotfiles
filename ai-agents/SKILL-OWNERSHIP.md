# Skill ownership

Ownership is explicit by source directory. Skills are portable by default; runtime-native
skills are reserved for instructions that directly require one runtime's hooks, tools, state,
or orchestration surface. PR #63 changes only source layout, not skill classification.

## Portable (`ai-agents/skills/`)

This is the canonical home for runtime-neutral Agent Skills. It is projected to Claude Code,
Codex CLI, and Pi where each runtime is configured to load it. This includes `council`,
`council-code`, `council-business`, `council-plan`, and `council-doc`.

## Portable support (`ai-agents/_shared/`)

Source-only portable review support resources live here. The directory has no `SKILL.md` and
is never projected as a standalone skill. Its files are independently owned from Claude's
projected support copy and the two directories may diverge.

## Claude-native (`claude/skills/`)

- `_shared` — Claude review-support resources, projected with Claude skills
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

Claude-native skills are projected only to Claude Code, while portable skills are projected
there alongside them. If names collide, the Claude-native variant wins.

## Codex-native (`codex/skills/`)

Codex-native variants live here only when they must differ from a portable skill and win name
collisions during projection. The directory is currently empty. Linux Codex projection is a
follow-up requirement, not part of this layout migration.

## Pi-native (`pi/skills/`)

Pi-native variants remain in the Pi runtime module and win name collisions over portable
skills during both Windows and Linux projection.

## Agents

Agent definitions under `ai-agents/shared/agents/` remain unchanged in this PR. They use
Claude Code's flat agent-file adapter and are projected only to `~/.claude/agents/`; the
directory name means shared repository ownership, not cross-runtime projection. Codex has no
separate top-level agent directory, and Pi packages/extensions provide isolation.
