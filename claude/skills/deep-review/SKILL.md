---
name: deep-review
description: Multi-dimension cross-model code review of a branch diff or PR. Fans out parallel reviewers (correctness, security, performance, structural, architecture, conventions, tests) plus Codex, adversarially verifies the findings, and writes them to a findings store for fixing. Use when asked to "deep review", "review the branch/PR thoroughly", "multi-dimension review", "find all the issues", or before running a fix loop. Reach for it from review-fix-loop. NOT for non-diff artifacts (ideas, designs-as-docs, plans, presentations) — use the council skill for those.
---

# Deep Review

Fan out parallel reviewers over a diff, verify what they find, write survivors to the store. This
skill **emits** findings; it does not fix them (that's `fix-findings`). It is the review half of
`review-fix-loop` and is independently invocable.

Contracts: the quality bar is [`../_shared/review-rubric.md`](../_shared/review-rubric.md), the seven
reviewers are [`../_shared/dimensions.md`](../_shared/dimensions.md), the record schema + store
discipline are [`../_shared/findings-schema.md`](../_shared/findings-schema.md). Read all three before
running — they define the output and the rules below depend on them.

## Quick start

```
/deep-review [ref-or-range | --pr <n>] [--floor MEDIUM]
```

Default scope is the current branch vs its merge-base with `main`. See [REFERENCE.md](REFERENCE.md)
for PR resolution (GitHub / Azure DevOps) and arg detail.

---

## Pipeline

```
SCOPE → FAN OUT → DEDUPE → VERIFY → EMIT
```

The **orchestrator** (you) is the sole writer of the store. Reviewers and verifiers run as subagents
and **return** their findings to you; you write every record. Never let a subagent write the store.

### Step 1 — Scope

1. Resolve the diff to git refs (see [REFERENCE.md](REFERENCE.md) for `--pr` resolution). Capture the
   **merge-base SHA once** as `base_sha` and the current branch head as this cycle's `head_sha`.
2. Resolve the snapshot by `review_session_id = repo + base_sha + initial_head_sha + worktree-path`
   (findings-schema.md). On cycle 1, `initial_head_sha = head_sha` and the id is frozen for the whole
   session — later cycles reuse the same snapshot even though HEAD has advanced, so dedupe sees prior
   findings. Record `reviewers_enabled` (the 7 dimensions, plus `codex` only if its MCP is present —
   if absent, omit it cleanly; never fail or lower the floor). Append a new per-cycle ledger entry
   (`cycle_id`, this cycle's `head_sha`).

**Done when:** `base_sha` + the frozen `review_session_id` are fixed, the snapshot + `reviewers_enabled`
exist, and this cycle's ledger entry is open.

### Step 2 — Fan out

Dispatch **one subagent per enabled reviewer in a single message** (parallel), each with its charter
from `dimensions.md` and the rubric bar. Include `codex` as a cross-model reviewer over the full
rubric when its MCP is present (this is the documented standing-consent exception — see CLAUDE.md).

Each reviewer returns candidate findings in the schema, each carrying `dimension`, `severity`,
`confidence`, a proposed `fix_verification`, `summary`, `fix_approach`, `evidence`, and `scope`. The
`architecture` reviewer reads beyond the diff; the rest are diff-local.

**Done when:** every enabled reviewer has returned. A reviewer that errors or returns nothing is
recorded as **run metadata** (`reviewer`, `error`, `cycle_id`) — never as a finding, never silently
dropped (findings-schema.md). Write all actual candidates to the store at `status: candidate`.

### Step 3 — Dedupe

Dedupe in a single pass (findings-schema.md), keeping every member's `evidence`: cluster candidates by
**fingerprint** (`file + scope + issue_kind + subject` — `dimension` is excluded), so a defect seen
through several lenses (a wrapper flagged by `structural` + `architecture` + `codex`) lands in one
cluster automatically. For the merged finding set `severity` to the highest among members,
`contributing_dimensions` to the sorted set, and the display `dimension` to the highest-severity
contributor (ties alphabetical). Assign `origin` + `origin_reason` against the frozen `base_sha`. Do
**not** force-collapse genuinely distinct issues (they differ in `issue_kind`/`subject`).

**Done when:** every candidate belongs to exactly one fingerprint cluster with `contributing_dimensions`,
a severity, and an origin.

### Step 4 — Verify (selective, adversarial)

Verify a finding only when it is **at or above the floor**, OR it is a `security`/`correctness`
finding the reviewer marked `confidence: low`. Skip verify for everything below that (it still enters
the store to be **reported** — `fix-findings` only auto-fixes above-floor findings — it just isn't
adversarially checked).

For each selected cluster, dispatch a verifier subagent (and Codex as a second voice when present)
**prompted to REFUTE** the finding — default to false-positive if uncertain. Verify the cluster, not
a lone member.

- Confirmed → `status: confirmed`, `adversarial_verified: true`.
- Refuted → `status: not_reproduced` (kept as a record, not deleted).
- Not selected for verify (below floor, or not low-confidence security/correctness) → `status:
  confirmed`, `adversarial_verified: false` — still a real finding, just not independently checked.

**Done when:** no finding is left at `candidate` — every one is `confirmed` or `not_reproduced`.

### Step 5 — Emit

All `confirmed` findings stay `confirmed`; `origin` (not status) is what distinguishes `introduced`
(fixable) from `pre-existing` (reported only) — `fix-findings` filters on it. Close this cycle's
ledger entry: write `observed_fingerprints`, `confirmed_introduced` (confirmed + introduced + above
floor), and `verified_absent` (fingerprints fixed in a prior cycle that this review did not surface).
Print a tight summary grouped by severity (confirmed introduced first, then pre-existing, then a
`not_reproduced` count), with the snapshot path.

**Done when:** the store reflects every finding's terminal review state, the ledger entry is closed,
and the summary is printed.

---

## Notes

- **Emit, don't fix.** Applying fixes is `fix-findings`. Running both in a loop is `review-fix-loop`.
- **Model.** Standalone, reviewers may run on Fable for a light pass. Invoked from `review-fix-loop`,
  they inherit its constraint — **Opus or Sonnet, never Fable** unless the user explicitly asks.
- **Sole writer.** Subagents return findings; you write the store. This is what makes parallel
  reviewers safe without locks (findings-schema.md).
- **Floor affects verify + reporting, not what's stored.** Below-floor findings are still recorded.
- A failed/empty reviewer is noted, never silently dropped — an empty result is a finding about the
  reviewer, not proof of clean code.
