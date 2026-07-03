---
name: prompt-draft
description: Draft a new prompt from a task description, applying the 12-lever prompting checklist from scratch. Use when the user wants to write, draft, compose, or create a new prompt, system prompt, or subagent prompt for a task that doesn't exist yet — not for reviewing or fixing a prompt that already exists (use prompt-lint for that).
argument-hint: "[task description the prompt is for]"
---

# Prompt Draft

Build a new prompt from a task description, applying
[`../prompt-lint/references/levers.md`](../prompt-lint/references/levers.md) — the shared
12-lever checklist — from a blank page.

## Process

1. **Get the task.** If the user gave a task description, use it. If it's thin (no audience, no
   downstream consumer, no format expectation), ask the minimum needed to fill lever 1
   (purpose+audience) and lever 7 (output format) — don't guess load-bearing details.
2. **Draft.** Write the prompt, applying every lever from
   `../prompt-lint/references/levers.md` that's applicable to this task (some, like lever 10
   provenance, only apply to research/citation prompts — mark those `n/a`). Never write a standing
   demand for the target model's private step-by-step reasoning (lever 5) — ask for rationale +
   assumptions + evidence instead.
3. **Confirm.** Walk the same checklist and confirm each applicable lever is addressed in what
   you just wrote.

## Output contract

Always in this order, nothing else:

1. **Drafted prompt** — ready to paste.
2. **Scorecard** — a table: lever | addressed/n/a | one-line evidence from the drafted prompt.

## Example

Task: "I need a prompt for a subagent that reviews Terraform plans for cost regressions before
they merge."

Drafted prompt: "Review the attached `terraform plan` output for cost regressions before this PR
merges — the reviewer (a platform engineer) needs a decision, not a tour of the diff. Flag any
resource whose plan implies a cost increase (new resource, size/tier bump, count increase); ignore
resources being destroyed or unchanged. For each flagged resource: name, the specific change, and
a rough monthly cost delta if it can be derived from the plan (say 'unknown' if it can't). Don't
flag tagging-only or metadata-only changes. Output: a markdown table (resource | change | est.
cost delta), capped at 20 rows, plus one line verdict (`ok to merge` / `needs cost review`)."

(Scorecard omitted here for brevity — a real run lists all 12 levers with addressed/n/a.)
