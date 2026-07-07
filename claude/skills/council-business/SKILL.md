---
name: council-business
description: "Adversarial review council for BUSINESS ideas and cases: startup/product ideas, business cases, investment or build-vs-buy proposals. Seats customer-market, unit-economics, competition-moat, go-to-market, legal-regulatory, execution, and premortem critics; debate round; chair verdict. Use when asked to red-team, stress-test, or council-review a business idea or case. NOT for technical designs (use council-code), project plans (council-plan), or documents (council-doc). Thin alias: pins the business panel and delegates to the council skill."
metadata:
  author: justin
  version: "1.0.0"
---

# Council — business panel (alias)

This is a thin wrapper over the [`council`](../council/SKILL.md) skill with the panel
pinned to **`business`**. Read that skill and its
[`perspectives.md`](../council/references/perspectives.md) registry, then run its full
pipeline (`SELECT → BRIEF → CRITIQUE → DEBATE → JUDGE → REPORT`) exactly as written, with:

- panel = `business` (no auto-detection); seat `contrarian` by default when the ask is
  go/no-go, per the engine's SELECT rules;
- all other arguments pass through unchanged (`target`, `+seat`/`-seat`, `--quick`).

Everything else — blind round-1, new-evidence rebuttals, codex seat, chair verdict, report
file — is the engine's, defined once there. Do not restate or vary the pipeline here.
