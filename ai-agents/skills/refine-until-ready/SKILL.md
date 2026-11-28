---
name: refine-until-ready
description: Review a change and fix what blocks it, in small in-scope fixes, until nothing blocking is left. Each cycle runs code-review, then fix-findings, re-runs prove-it's case when there is one, and stops when the change is ready or a rail trips (cap, scope, size budget, reappearance, oscillation, no progress). Use when asked to "review and fix", "fix all issues", "clean up the branch", "review until green", "refine until ready", "iterative review loop", or "keep fixing until clean".
---

# Refine Until Ready

Review a change and fix what blocks it, in small in-scope fixes, until nothing blocking is left.

This skill is a thin orchestrator. [`code-review`](../code-review/SKILL.md) emits findings,
[`fix-findings`](../fix-findings/SKILL.md) fixes them, and this skill decides whether to go
again. It owns the loop, the ready gate and the rails. It does not review or fix anything
itself. The store, the ledger and the rail definitions are in
[`../_shared/findings-schema.md`](../_shared/findings-schema.md).

## Quick start

```
/refine-until-ready [ref-or-range | --pr <n>] [--cap 5]
```

The scope argument goes to `code-review` step 1. `--cap` sets the cycle limit (default 5). The
blocking floor is fixed at MED: HIGH and MED findings block, and LOW findings are only reported.

## Cycle

```
code-review → fix-findings → prove-it case → evaluate → repeat | stop
```

1. Review. Run `code-review`. Cycle 1 reviews the full diff against the frozen base and fixes
   `base_sha` and `review_session_id`. Each later cycle reviews only the delta since the previous
   cycle's head, and checks that every fingerprint fixed in an earlier cycle is still absent.
   A finding outside that delta goes to the final report and does not enter the loop. Record the
   range in the ledger's `reviewed_range`.
2. Fix. Run `fix-findings` on the open blocking findings. It returns `suite_green`,
   `lint_clean`, the fixed and rejected fingerprints, and any scope breach.
3. Prove. When `prove-it` established a base-versus-branch case for this change (see
   [`../prove-it/SKILL.md`](../prove-it/SKILL.md)), run that case again on the new head. A
   behaviour regression is a blocking finding (lens `bugs`, origin `introduced`) for the next
   cycle.
4. Evaluate the ready gate, then the rails. Go again or stop.

### Ready gate

Stop and report "Ready" when all of these hold:

- No confirmed, introduced, blocking finding is left unfixed. Rejected, parked and accepted
  (`wontfix`) findings do not count.
- `fix-findings` returned `suite_green: true` and `lint_clean: true` for this cycle.
- The `prove-it` case, when there is one, shows no regression.

The loop uses the signals `fix-findings` returns. It does not run the tests or the linter again.

### Rails

When a rail trips, stop. Set each open blocking finding to `parked` with the rail as its
`status_reason`, then hand back to the user with the open findings and the reason.

| Rail | Trips when |
|---|---|
| cap | the cycle count reaches `--cap` (default 5) |
| scope | a fix touched a file outside its finding's `intended_files` |
| size budget | the cumulative lines changed by fixes (`fix_lines_added`) exceed 50% of the original diff's changed lines |
| reappearance | a fingerprint that an earlier cycle fixed comes back |
| oscillation | the open set returns to a state seen in an earlier cycle, for example A fixed, then B, then A again |
| no progress | a cycle fixes nothing and rejects nothing |

All rails work on fingerprints, never on line numbers (findings-schema.md).

## Final report

End with the outcome (Ready, or the rail that stopped the loop), the cycles run, the findings
fixed, rejected and parked with their reasons, the findings outside the reviewed deltas, the
pre-existing and LOW findings, and what was not covered.

## Notes

- Reviewer and fixer models: [`../_shared/reviewer-models.md`](../_shared/reviewer-models.md),
  including its Fixer pin section.
- Frozen base. Capture `base_sha` once on cycle 1. Every later cycle computes origin against it,
  so origin and the rails stay stable as fixes shift lines.
- User interrupt. Any message during the loop stops it at the next safe point: finish the
  in-flight worker batch, let the orchestrator write the store and commit any fix-unit already
  verified green, then stop before the next review, fix or commit step. The worktree and the
  store stay consistent.
- The working store lives under the runtime's own config home (`~/.claude/`, `~/.codex/`, or
  `~/.pi/`), outside the repo, and is never committed.
