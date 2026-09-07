---
name: critique-plan
description: Stress-test a drafted plan against the project's domain model before any code is written — terminology drift, wrong bounded context, ADR contradictions, bad dependency edges, reinvented concepts. Use before implementing from a spec or ticket set, or when the user asks to critique, pressure-test, or sanity-check a plan against the domain model.
metadata:
  status: trial
---

# Critique Plan (pre-implementation)

Stress-test a drafted plan against the project's domain model before any code is written. This
skill produces pushbacks, not suggestions — it never gold-plates a plan that is already sound.

Silence is the expected outcome. A plan that speaks the canonical language and respects the
documented decisions gets a one-line "No objections." Do not manufacture concerns to look
thorough.

"The plan" is whatever came out of `to-spec` or `to-tickets`, a set of tickets already on the
tracker, or whatever the user pastes in standalone.

## Process

### 1. Load the domain model

Read only what exists; skip missing files silently — don't flag them or offer to create them.
Look for `CONTEXT.md` (or `CONTEXT-MAP.md` plus each context's own `CONTEXT.md`, per
[domain-modeling](../domain-modeling/SKILL.md#file-structure)) and `docs/adr/`.

If neither exists, say so in one line and stop — there is no domain model to critique against.

### 2. Spin up one read-only domain critic

Dispatch a single isolated, read-only subagent with the plan verbatim and the files from step 1.
It returns pushbacks as text and edits nothing. Isolating it keeps the critique out of the
planning session's context. Its brief:

Fire only on a genuine conflict, one of:

- **Terminology drift** — the plan names a concept differently from the glossary/`CONTEXT.md`, or
  reuses a canonical term for a new meaning.
- **Wrong bounded context** — work placed in the wrong context, or a unit that straddles a
  documented boundary.
- **Contradicts an ADR** — reverses a recorded decision and the friction is real enough to reopen
  it. Cite `ADR-NNNN`.
- **Bad dependency edge** (ticket set) — a "blocked by" edge crosses a context boundary the wrong
  way, two "independent" tickets share a domain concept, or a ticket is mis-scoped (an epic, or
  several tickets dressed as one).
- **Reinvents a named concept** — introduces a new abstraction for something the domain model
  already names.

For each, return: **What** (the ticket/decision in question), **Conflicts with** (the exact
term / `CONTEXT.md` section / `ADR-NNNN`), **Why it matters** (concrete cost, not taste),
**Suggested resolution**.

Example pushback: "Ticket 3 calls it `archiveOrder`, but the glossary defines archiving as
retention only — this ticket also stops billing, which is Cancellation. Rename to `cancelOrder`
so the code matches the domain, or the two concepts will blur across the codebase."

A deliberately deferred decision the plan already marks as such (a stated placeholder, an
explicit TBD) is not a gap to flag — the user chose to defer it. Fire on it only if the
placeholder itself conflicts with the domain model: it contradicts an ADR, or it quietly
redefines a canonical term.

Out of scope for this critic: implementation quality, performance, tests, code style, "you could
also…" ideas — anything not anchored in the domain model. Those belong to `spec-review` (does the
diff match the spec) or `quick-review`/`deep-review` (code quality), which run after
implementation. With nothing anchored, the critic returns exactly:
`No objections — the plan is consistent with the domain model.`

### 3. Surface pushbacks — advisory, never blocking

Bring the pushbacks back into the planning session. The user resolves each their own way:

- **Accept** → amend the plan (rename, re-scope, fix the edge, move contexts) right there.
- **Dismiss** → drop it. If the dismissal rests on a load-bearing reason a future planner would
  need in order not to re-raise it, offer to record an ADR using
  [domain-modeling's ADR-FORMAT.md](../domain-modeling/ADR-FORMAT.md). Skip ephemeral ("not now")
  and self-evident reasons.

When a resolution sharpens a term, update `CONTEXT.md` inline using
[domain-modeling's CONTEXT-FORMAT.md](../domain-modeling/CONTEXT-FORMAT.md).

If the critic returned "No objections," say so in one line and move on. Don't pad it.

`grilling`/`domain-modeling` is a full interactive re-grill of the design; `critique-plan` is a
single-pass, silent-by-default gate — one critic, real conflicts only, then straight back to the
workflow.
