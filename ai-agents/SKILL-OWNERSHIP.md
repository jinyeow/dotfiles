# Skill ownership

Ownership is explicit by source directory. Shared skills are reviewed for runtime-neutral dependencies; Claude skills retain Claude hooks, orchestration, or integration coupling.

## Shared (`ai-agents/shared/skills/`)
- `bicep-tdd`
- `caveman`
- `diagnosing-bugs`
- `grill-with-docs`
- `grilling`
- `jj`
- `prototype`
- `quick-research`
- `resolving-merge-conflicts`
- `tdd`
- `teach`
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
- `prompt-draft`
- `to-hld`
- `triage`
- `wayfinder`
- `write`

Codex-specific variants are reserved under `ai-agents/codex/skills/`, while Pi-specific variants remain under `pi/skills/`; both are empty until a runtime-specific variant is required.
