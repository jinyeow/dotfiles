---
name: quick-review
description: The default review pass over a branch diff or PR. Use when asked to "review the diff", "review this branch", "review my changes", "review the PR", or for findings before a fix loop. Runs one folded reviewer (correctness + conventions + tests) plus Codex as a cross-model second opinion, adversarially verifies what they find, and writes it to the same findings store as deep-review. Reach for deep-review only when the heavier seven-dimension fan-out (security, performance, structural, architecture) is explicitly wanted. NOT for non-diff artifacts (ideas, designs-as-docs, plans, presentations) — use the council skill for those.
---

# Quick Review

The **default** review pass: two participants instead of eight. One folded reviewer subagent covering
`correctness` + `conventions` + `tests`, plus Codex as a cross-model second opinion. This skill
**emits** findings; it does not fix them (that's `fix-findings`). It is the default review half of
`review-fix-loop` and is independently invocable.

Same store, same schema, same dedupe/verify/emit pipeline as [`deep-review`](../deep-review/SKILL.md) —
**only the fan-out width differs**. Reach for `deep-review` when security, performance, structural, or
architecture coverage is actually wanted.

Contracts: the quality bar is [`../_shared/review-rubric.md`](../_shared/review-rubric.md), the
dimension charters are [`../_shared/dimensions.md`](../_shared/dimensions.md), the record schema +
store discipline are [`../_shared/findings-schema.md`](../_shared/findings-schema.md), and reviewer
model resolution is [`../_shared/reviewer-models.md`](../_shared/reviewer-models.md). Read them before
running — they define the output and the rules below depend on them.

## Quick start

```
/quick-review [ref-or-range | --pr <n>] [--floor MEDIUM] [--reviewers <model>[,<model>][:<effort>]]
```

Default scope is the current branch vs its merge-base with `main`. Scope resolution, `--pr` handling
(GitHub / Azure DevOps), and the store layout are shared with `deep-review` — see
[its REFERENCE](../deep-review/REFERENCE.md); they are not restated here.

---

## Pipeline

```
SCOPE → FAN OUT (2) → DEDUPE → VERIFY → EMIT
```

The **orchestrator** (you) is the sole writer of the store. Reviewers and verifiers run as subagents
and **return** their findings to you; you write every record. Never let a subagent write the store.

Steps 1, 3, 4 and 5 are `deep-review`'s, unchanged — same frozen `review_session_id`, same fingerprint
dedupe, same selective adversarial verify, same ledger close and summary. Two differences only:

- **Step 1 (Scope)** records `reviewers_enabled` as this skill's participant set — the folded reviewer
  and `codex` (only if its MCP is present; if absent, omit it cleanly, never fail or lower the floor) —
  plus whatever `--reviewers` resolved to. Not the seven dimensions.
- **Step 2 (Fan out)** is the folded dispatch below.

### Step 2 — Fan out (2 participants)

Dispatch both in a **single message** (parallel):

1. **The folded reviewer.** One subagent carrying the `correctness`, `conventions`, and `tests`
   charters from [`../_shared/dimensions.md`](../_shared/dimensions.md) verbatim, plus the rubric bar.
   Diff-local — it does not read beyond the diff.
2. **Codex**, as a cross-model reviewer over the **full** rubric, when its MCP is present (the
   documented standing-consent exception — see `claude/CLAUDE.md`). Call it with the read-only posture
   set explicitly per call:

   ```
   mcp__codex__codex
     approval-policy: never
     sandbox: read-only
     prompt: <the three charters + rubric substance + the diff>
   ```

   Model and `config: { model_reasoning_effort }` come from `--reviewers` when given — see
   [`../_shared/reviewer-models.md`](../_shared/reviewer-models.md).

**Every finding carries a registry dimension label from
[`../_shared/dimensions.md`](../_shared/dimensions.md)** — never a `quick` label. The label is
load-bearing downstream: the registry supplies the per-dimension default `fix_verification`, and
`fix-findings` keys its TDD gate off that field, so an unregistered dimension silently degrades a
`test`-verified fix to direct-apply.

The folded Claude reviewer only ever emits `correctness`, `conventions`, or `tests`. Codex stays a
**full-rubric** reviewer — that cross-model breadth is the point of the second participant — so it may
raise, say, a `security` or `architecture` finding. Record those under their real registry dimension;
they are stored, verified, reported, and fixable like any other. A `quick-review` snapshot is therefore
*single-sourced* outside the folded three (one contributor, no Claude cross-check) — say so in the
summary so the user can escalate to `deep-review` rather than mistake narrow coverage for a clean bill.

**Done when:** both participants have returned. A participant that errors or returns nothing is
recorded as **run metadata** (`reviewer`, `error`, `cycle_id`) — never as a finding, never silently
dropped (findings-schema.md). Write all actual candidates to the store at `status: candidate`.

---

## Args

| Arg | Default | Meaning |
|---|---|---|
| `ref-or-range` / `--pr <n>` | `main...HEAD` (merge-base) | git refs to review (see deep-review's REFERENCE) |
| `--floor <sev>` | `MEDIUM` | severity floor for verify + reporting (not for what's stored) |
| `--reviewers <spec>` | skill defaults | reviewer models + effort ([`../_shared/reviewer-models.md`](../_shared/reviewer-models.md)) |

Here the reviewer set stays two: the **first** Claude alias in `--reviewers` becomes the folded
reviewer's model and any Codex alias (`sol`, `codex`) becomes Codex's — further Claude aliases are
rejected with that explanation, since adding participants is `deep-review`, not this skill.

All three are scoping inputs (what gets reviewed / verified / by whom), not logic switches.

---

## Notes

- **Emit, don't fix.** Applying fixes is `fix-findings`. Running both in a loop is `review-fix-loop`,
  which invokes this skill by default.
- **Model.** Standalone, the folded reviewer may run on Fable for a light pass. Invoked from
  `review-fix-loop`, it inherits that loop's reviewer constraint. `--reviewers` overrides both — and is
  reviewer-only: it never changes which model a fixer runs on.
- **Sole writer.** Subagents return findings; you write the store. This is what makes parallel
  participants safe without locks (findings-schema.md).
- **Two participants is the point.** Codex's full-rubric brief is not a licence to add participants:
  when a diff needs *dedicated* security, performance, structural, or architecture reviewers, that is
  `deep-review`. Never dispatch a third reviewer here.
- A failed/empty participant is noted, never silently dropped — an empty result is a finding about the
  reviewer, not proof of clean code.
