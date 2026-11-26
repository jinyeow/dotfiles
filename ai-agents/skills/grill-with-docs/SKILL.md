---
name: grill-with-docs
description: Grilling session that challenges your plan against the existing domain model, sharpens terminology, and updates documentation (CONTEXT.md, ADRs) inline as decisions crystallise. Use when user wants to stress-test a plan against their project's language and documented decisions.
disable-model-invocation: true
---

Run a [`grilling`](../grilling/SKILL.md) session — the relentless, frontier-round interview to reach shared understanding. While you grill, run [`domain-modeling`](../domain-modeling/SKILL.md) alongside it, so the project's domain docs (`CONTEXT.md`, ADRs) get maintained inline as decisions crystallise.

Read both files and follow them together: `grilling` for the interview mechanics, `domain-modeling` for the docs discipline. Read them by path rather than loading them as skills, because `grilling` is user-invoked only.
