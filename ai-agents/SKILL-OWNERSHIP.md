# Skill ownership

Ownership is explicit by source directory. Shared skills are reviewed for runtime-neutral dependencies; Claude skills retain Claude hooks, orchestration, or integration coupling.

## Shared (`ai-agents/shared/skills/`)
- `bicep-tdd`
- `caveman`
- `diagnosing-bugs`
- `grill-with-docs`
- `grilling`
- `jj`
- `prompt-draft`
- `prototype`
- `quick-research`
- `resolving-merge-conflicts`
- `tdd`
- `teach`
- `to-hld`
- `triage`
- `wayfinder`
- `write`
- `zoom-out`

## Claude-only (`ai-agents/claude/skills/`)
- `_shared`
- `azure-boards-organiser`
- `azure-compliance`
- `azure-devops`
- `azure-enterprise-infra-planner`
- `azure-pipelines`
- `azure-prepare`
- `azure-resource-manager`
- `azure-validate`
- `codebase-design`
- `codex-review`
- `council`
- `council-business`
- `council-code`
- `council-doc`
- `council-plan`
- `deep-review`
- `fastmail`
- `fix-findings`
- `git-guardrails-claude-code`
- `handoff`
- `health`
- `implement`
- `improve-codebase-architecture`
- `linkedin-jobs`
- `project-brain`
- `prompt-lint`
- `review-ado-pr`
- `review-fix-loop`
- `router`
- `setup-agent-skills`
- `spec-review`
- `storm-research`
- `to-spec`
- `to-tickets`
- `walkthrough`
- `writing-great-skills`

Codex and Pi-specific directories are reserved under `ai-agents/codex/skills/` and `ai-agents/pi/skills/`; they are empty until a runtime-specific variant is required.
