---
name: council-plan
description: "Adversarial review council for PLANS: project plans, roadmaps, migration or rollout plans, delivery schedules. Seats premortem, critical-path, estimation-realism, scope-sequencing, measurability, and stakeholder-impact critics; debate round; chair verdict. Use when asked to red-team, stress-test, or council-review a plan, roadmap, or schedule. NOT for technical designs (use council-code), business ideas (council-business), or documents (council-doc). Thin alias: pins the plan panel and delegates to the council skill."
metadata:
  author: justin
  version: "1.0.0"
---

# Council — plan panel (alias)

This is a thin wrapper over the [`council`](../council/SKILL.md) skill with the panel
pinned to **`plan`**. Read that skill and its
[`perspectives.md`](../council/references/perspectives.md) registry, then run its full
pipeline (`SELECT → BRIEF → CRITIQUE → DEBATE → JUDGE → REPORT`) exactly as written, with:

- panel = `plan` (no auto-detection);
- all other arguments pass through unchanged (`target`, `+seat`/`-seat`, `--quick`).

Everything else — blind round-1, new-evidence rebuttals, codex seat, chair verdict, report
file — is the engine's, defined once there. Do not restate or vary the pipeline here.
