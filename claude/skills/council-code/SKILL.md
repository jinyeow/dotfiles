---
name: council-code
description: "Adversarial review council for TECHNICAL designs: architecture/design docs, ADRs, API or approach proposals, infra designs. Seats security, architecture, performance-scale, operability, compliance-privacy, simplicity, and testability critics; debate round; chair verdict. Use when asked to red-team, stress-test, or council-review a technical design or ADR. NOT for a branch diff or PR (use deep-review) and NOT for business ideas/plans/documents (use council-business / council-plan / council-doc). Thin alias: pins the code panel and delegates to the council skill."
metadata:
  author: justin
  version: "1.0.0"
---

# Council — code/design panel (alias)

This is a thin wrapper over the [`council`](../council/SKILL.md) skill with the panel
pinned to **`code`**. Read that skill and its
[`perspectives.md`](../council/references/perspectives.md) registry, then run its full
pipeline (`SELECT → BRIEF → CRITIQUE → DEBATE → JUDGE → REPORT`) exactly as written, with:

- panel = `code` (no auto-detection);
- all other arguments pass through unchanged (`target`, `+seat`/`-seat`, `--quick`).

Everything else — blind round-1, new-evidence rebuttals, codex seat, chair verdict, report
file — is the engine's, defined once there. Do not restate or vary the pipeline here.
