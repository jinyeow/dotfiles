---
name: council-doc
description: "Adversarial review council for DOCUMENTS and presentations: slide decks, proposals, reports, important emails or papers. Seats audience-fit, narrative-logic, evidence-audit, clarity-structure, and hostile-reader critics; debate round; chair verdict. Use when asked to red-team, stress-test, or council-review a presentation or document before an audience sees it. NOT for technical designs (use council-code), business ideas (council-business), or plans (council-plan). Thin alias: pins the doc panel and delegates to the council skill."
metadata:
  author: justin
  version: "1.0.0"
---

# Council — doc/presentation panel (alias)

This is a thin wrapper over the [`council`](../council/SKILL.md) skill with the panel
pinned to **`doc`**. Read that skill and its
[`perspectives.md`](../council/references/perspectives.md) registry, then run its full
pipeline (`SELECT → BRIEF → CRITIQUE → DEBATE → JUDGE → REPORT`) exactly as written, with:

- panel = `doc` (no auto-detection);
- all other arguments pass through unchanged (`target`, `+seat`/`-seat`, `--quick`).

Everything else — blind round-1, new-evidence rebuttals, codex seat, chair verdict, report
file — is the engine's, defined once there. Do not restate or vary the pipeline here.
