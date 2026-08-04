---
name: council-plan
description: "Thin council alias for project plans, roadmaps, and migrations. Pins the plan panel; not for branch diffs or PRs."
metadata:
  author: justin
  version: "2.0.0"
---

# Council — plan panel alias

Read and run the shared [`council`](../council/SKILL.md) contract with `panel = plan`.
The panel is pinned: reject a conflicting positional panel rather than overriding it.
Pass through the target and all supported arguments unchanged: `--mode quick|debate`,
`--quick`, `--debate`, `--seats 2..5`, `+seat`, `-seat`, and `--codex`.

Do not duplicate or vary selection, dispatch, budget, verdict, failure, or report policy
here. The shared engine's quick default and opt-in debate/Codex rules apply.
