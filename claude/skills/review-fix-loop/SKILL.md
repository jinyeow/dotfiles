---
name: review-fix-loop
description: Iterative review-fix cycle for a branch or PR. Chains quick-review by default (or deep-review under --deep) with fix-findings (apply + commit fixes) each cycle, then loops until the review passes clean at the severity floor or a safety rail trips. Use when asked to "review and fix", "fix all issues", "clean up the branch", "iterative review loop", "review until no issues", or "keep fixing until clean".
---

# Review-Fix Loop

A **thin orchestrator**. Each cycle it invokes the review skill then `fix-findings`, then evaluates a
deterministic gate. It owns only the looping, the gate, the rails, and the state transitions between
the two skills — it does not review or fix itself.

Composition: [`quick-review`](../quick-review/SKILL.md) — or [`deep-review`](../deep-review/SKILL.md)
under `--deep` — emits findings → [`fix-findings`](../fix-findings/SKILL.md) consumes them → this loop
evaluates the gate and decides whether to go again. Both reviewers write the same store, so the fix
half and the rails are identical either way. Shared store + fingerprint + rail definitions:
[`../_shared/findings-schema.md`](../_shared/findings-schema.md).

## Quick start

```
/review-fix-loop [ref-or-range | --pr <n>] [--floor MEDIUM] [--cap 8] [--deep] [--reviewers <model>[,<model>][:<effort>]]
```

---

## Loop

```
quick-review → fix-findings → GATE? → repeat | stop
```

(`deep-review` replaces the first stage under `--deep`.) Each cycle:

1. **Review** — invoke `quick-review` (or `deep-review` under `--deep`), passing `--floor` and
   `--reviewers` through. The choice is fixed for the whole run — do not switch reviewers mid-loop, or
   the ledger's absent/reappeared fingerprints stop being comparable across cycles.
   Cycle 1 fixes `base_sha` + the frozen `review_session_id`; every
   later cycle diffs the **same frozen `base_sha`** against the current HEAD (which the loop's own
   commits have advanced) and reuses the same session snapshot, so the per-cycle ledger distinguishes
   fixed / absent / reappeared fingerprints. It writes confirmed findings to the store.
2. **Fix** — invoke `fix-findings`. It fixes the confirmed `introduced` above-floor findings, runs the
   full suite + full-tree lint, commits one fix-unit at a time, and returns `suite_green` /
   `lint_clean`.
3. **Evaluate** the gate and rails (below) using the store ledger + the returned signals, then repeat
   or stop.

### Clean gate — exit success

Stop and report **"Review clean"** when all three hold:

- Zero `confirmed` `introduced` findings **at or above the floor** (default MEDIUM) remain unfixed
  (read from the store), and
- `fix-findings` returned `lint_clean: true` and `suite_green: true` for the cycle.

The loop relies on `fix-findings`' returned gate signals — it does not re-run lint/tests itself.
Below-floor findings (LOW/CLEANUP) and pre-existing findings are reported, not gated on.

### Safety rails — stop and escalate

Stop, hand back to the user, and print the remaining store + the reason, if any of:

- **Cap** — cycle count reaches `--cap` (default 8).
- **Reappearance** — a fingerprint returns as `introduced` above floor after being marked `fixed` and
  verified-absent the previous cycle (a fix didn't hold).
- **No-progress** — a cycle resolves no above-floor fingerprint and reduces no above-floor severity
  (excluding newly discovered pre-existing findings).

Reappearance + no-progress are defined on **fingerprints**, not line numbers (findings-schema.md).

---

## Args

| Arg | Default | Meaning |
|---|---|---|
| `ref-or-range` / `--pr <n>` | `main...HEAD` | scope, passed to the review skill (see deep-review's REFERENCE) |
| `--floor <sev>` | `MEDIUM` | gate + verify floor |
| `--cap <n>` | `8` | max cycles before escalating |
| `--deep` | off | run `deep-review` (7 dimensions + Codex) instead of the default `quick-review` |
| `--reviewers <spec>` | reviewer-skill defaults | reviewer models + effort, passed through ([`../_shared/reviewer-models.md`](../_shared/reviewer-models.md)) |

Floor, cap, and reviewers are scoping inputs (which findings gate / how many cycles / which models),
not logic switches. `--deep` selects which review skill the loop composes with; it does not change the
loop's own gate, rails, or store handling.

---

## Notes

- **Reviewer model.** The review child runs on **Opus or Sonnet — never Fable** unless the user
  explicitly asks. (Fable is fine for a standalone light review or the plan stage, but not for this
  automated find-and-commit loop.) `--reviewers` overrides this per run —
  [`../_shared/reviewer-models.md`](../_shared/reviewer-models.md).
- **Fixer model.** Fixers apply and commit code, so they stay pinned regardless of `--reviewers`:
  **Opus 4.8 / 4.7 / 4.6, or Sonnet 5 (or lower) — never Opus 5, never Fable**, for now, unless the
  user explicitly asks. Dispatch with the `model` param set to a version that satisfies this; the bare
  `opus` alias resolves to the current default Opus (Opus 5 today) and therefore does **not** satisfy
  the pin — name the version explicitly, or ask the user rather than guessing.
- **Thin.** Reviewing is `quick-review` / `deep-review`; fixing is `fix-findings`. This skill sequences
  them, owns the store's state transitions across cycles, and decides stop-vs-go. Don't reimplement
  review or fix here.
- **Frozen base.** Capture `base_sha` once on cycle 1; every later cycle re-reviews against it so
  origin classification and the rails stay stable as fixes shift lines.
- **User interrupt** — any message during the loop stops it at the next safe point: finish the
  in-flight subagent batch, let the orchestrator write the store + commit any fix-unit already verified
  green, then stop without starting a new review/fix/commit step. Leaves the worktree + store
  consistent.
- Working store lives under `~/.claude/`, outside the repo — never committed.
