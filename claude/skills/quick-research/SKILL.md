---
name: quick-research
description: Delegate lightweight reading legwork to a background agent — investigate a question against primary sources and capture the findings as a short cited Markdown file in the repo, so you keep working while it reads. Use for quick primary-source fact-gathering (docs, APIs, specs). For a deep multi-source report use the built-in deep-research; for a multi-perspective briefing use storm-research.
disable-model-invocation: true
---

# Quick Research

Spin up a **background agent** to do the reading, so you keep working while it investigates.

Its job:

1. Investigate the question against **primary sources** — official docs, source code, specs, first-party APIs — not a secondary write-up of them. Follow every claim back to the source that owns it.
2. Write the findings to a single Markdown file, **citing each claim's source**. Where the sources don't settle a point, say **"unknown"** rather than guessing.
3. Save it where the repo already keeps such notes — match the existing convention; if there is none, put it somewhere sensible and say where.

Take the file it produces *into* your thinking — e.g. `/grill-with-docs`. Research feeds the design; it doesn't replace it.
