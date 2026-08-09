---
name: quick-review
description: Light cross-model code review of a branch diff or PR. Runs one folded reviewer (correctness + conventions + tests) plus Codex as a second opinion, verifies what they find, and writes it to the same findings store as deep-review. Use when asked to "review the branch/PR", "review and fix", or before a fix loop — this is the default reviewer for review-fix-loop. Reach for deep-review instead when all seven dimensions (security, performance, structural, architecture) are wanted. NOT for non-diff artifacts (ideas, designs-as-docs, plans, presentations) — use the council skill for those.
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

**Each finding must carry one of the three existing dimension labels** — `correctness`, `conventions`,
or `tests` — never a `quick` label. The label is load-bearing downstream: `dimensions.md` supplies the
per-dimension default `fix_verification`, and `fix-findings` keys its TDD gate off that field, so an
unregistered dimension silently degrades a `test`-verified fix to direct-apply. Codex findings are
labelled the same way; anything Codex raises outside those three dimensions is still recorded under its
real dimension (it is a full-rubric reviewer) — the fold narrows the *Claude* reviewer, not the store.

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
- **Two participants is the point.** If a review needs security, performance, structural, or
  architecture coverage, that is `deep-review` — do not widen the fan-out here.
- A failed/empty participant is noted, never silently dropped — an empty result is a finding about the
  reviewer, not proof of clean code.
