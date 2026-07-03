---
name: prompt-lint
description: Score, critique, and rewrite an existing prompt against the 12-lever prompting checklist — output format, acceptance criteria, scope, and reasoning-extraction risk. Use when the user wants to lint, score, critique, review, audit, or improve an existing prompt, system prompt, subagent prompt, or prompt file.
argument-hint: "[prompt text or path to a prompt file]"
---

# Prompt Lint

Score an existing prompt against [`references/levers.md`](references/levers.md) — the shared
12-lever checklist — then rewrite it to close the gaps. Read the checklist before scoring; every
score needs it.

## Process

1. **Get the prompt.** If the user pointed at a file, read it. If they pasted text, use that
   directly. If neither, ask which prompt to lint.
2. **Score.** Walk all 12 levers from `references/levers.md`. For each: `hit`, `miss`, or `n/a`,
   with a one-line evidence quote or paraphrase from the prompt. Flag lever 5 (reasoning
   extraction) as **HIGH** severity on any miss — it risks a silent Fable→Opus fallback, not just
   weaker output.
3. **Rewrite.** Produce a corrected prompt that closes every `miss`, keeps every `hit`, and
   shortens padded sections (lever 6) — restated procedure, redundant caveats, filler. Do not add
   scope beyond what the original prompt asked for.

## Output contract

Always in this order, nothing else:

1. **Scorecard** — a table: lever | hit/miss/n/a | evidence.
2. **Rewritten prompt** — the full corrected prompt, ready to paste.
3. **Diff summary** — one line: what changed and why.

## Examples

<example-1>
Before: "Analyze this codebase and explain your reasoning step by step for every architectural
decision you'd make. Refactor whatever needs refactoring. Don't touch the tests."

Miss: lever 1 (no purpose/audience stated), lever 5 (HIGH — demands step-by-step reasoning),
lever 2 (negative-only: "don't touch the tests" has no paired positive), lever 7/9 (no format or
acceptance criteria).

After: "Audit `src/` for architecture issues that block the Q3 API migration (see #142). For each
issue, give a short rationale + evidence (file:line) — not a reasoning narrative. Refactor
non-test source files only; leave `tests/` as read reference for behavior to preserve. Output: a
markdown list of findings, each with file, issue, and proposed fix, capped at 15 items."
</example-1>

<example-2>
Before: "Write a summary of the attached research paper. Be thorough. Make sure to be
comprehensive and don't miss anything important. Read the whole paper carefully first, then think
about the structure, then write section by section, checking each section against the source
before moving on to the next."

Miss: lever 7 (no length cap or structure named), lever 10 (no provenance rule for a research
summary), lever 6 (the "read carefully / think / check each section" is procedure the model
already does — no-op padding).

After: "Summarize the attached paper for someone deciding whether to read it in full. Cover:
claim, method, key result, and one limitation. Quote or cite the page/section for every claim.
Say 'unknown' rather than inferring where the paper doesn't state something directly. Output:
200-300 words, plain prose, no headers."
</example-2>
