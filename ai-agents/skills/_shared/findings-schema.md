# Findings Store — schema, fingerprint, store discipline

Shared contract for the review→fix skills: **`deep-review` emits**, **`fix-findings` consumes**,
**`review-fix-loop` owns the loop-level cycle + rail decisions**. Each invoked skill's orchestrator
owns its own status writes (deep-review: `candidate`→`confirmed`/`not_reproduced`; fix-findings:
`fixing`→`fixed`); the loop does not reach in to set them. The store is the composition seam — each
skill's I/O is explicit; no skill reaches into another's internals.

Quality bar + severity scale: [`review-rubric.md`](review-rubric.md). Dimensions:
[`dimensions.md`](dimensions.md).

---

## Record schema (JSONL — one finding per line)

| Field | Type | Notes |
|---|---|---|
| `id` | string | unique within a run |
| `fingerprint` | string | **semantic** identity — see below; drives dedup / reappearance / no-progress |
| `repo` | string | canonical repo id: normalized origin remote URL (stable across machines); root-path hash only as fallback |
| `base_sha` | string | frozen merge-base SHA captured at run start |
| `head_sha` | string | branch head SHA at review time (SHA, not branch name) |
| `file` | string | path relative to repo root |
| `scope` | string | enclosing symbol (function/class/block); fallback `module` / `top-level` / config-key-path / test-name / md-heading |
| `lines` | string | **display-only** (e.g. `120-134`); never part of identity |
| `dimension` | enum | primary dimension (display only): highest-severity contributor, ties broken alphabetically — deterministic. One of `correctness` \| `security` \| `performance` \| `structural` \| `architecture` \| `conventions` \| `tests` \| `codex` |
| `contributing_dimensions` | string[] | every dimension that reported this defect (sorted) |
| `severity` | enum | `CRITICAL` \| `HIGH` \| `MEDIUM` \| `LOW` \| `CLEANUP` (see review-rubric.md) |
| `origin` | enum | `introduced` \| `pre-existing` |
| `origin_reason` | enum | `changed_hunk` \| `new_call_path` \| `new_config_exposure` \| `new_dependency` (required when `origin=introduced`) |
| `fix_verification` | enum | `test` \| `lint` \| `manual-static` \| `not-applicable` — how the FIX is validated; `test` ⇒ TDD |
| `confidence` | enum | reviewer self-rating `high` \| `low` (feeds selective verify) |
| `adversarial_verified` | bool | true once a verifier subagent has confirmed the finding |
| `intended_files` | string[] \| null | files the fix will touch; may be null at review time, resolved before fix-scheduling |
| `status` | enum | `candidate` \| `confirmed` \| `fixing` \| `fixed` \| `not_reproduced` \| `wontfix` |
| `summary` | string | one-line problem statement |
| `fix_approach` | string | concrete remedy (prefer "delete X" over "rename Y") |
| `evidence` | object | `{ hunk, snippet_hash, rationale }` — why it's real; for `introduced`, why the diff caused it |

Validate every record against this schema before writing. An invalid record fails that subagent's
result — it does not enter the store.

### Status lifecycle

```
candidate ──(selected & verifier confirms)──▶ confirmed ──▶ fixing ──▶ fixed
    │       ├─(not selected for verify)──────▶ confirmed (adversarial_verified=false)
    │       └─(verifier refutes)─────────────▶ not_reproduced
    └─(user declines a confirmed finding)────▶ wontfix
```

- `candidate` — emitted by a reviewer; not yet resolved. **No finding stays here** after verify.
- `confirmed` — a real finding to act on. `adversarial_verified=true` if it passed adversarial verify;
  `false` if it was below the verify selection (still real, just not independently checked).
- `fixing` / `fixed` — `fixed` is set only **after** the fix's `fix_verification` passes (test green /
  lint clean / static check) **and** the commit lands.
- `not_reproduced` — verifier refuted it (false positive); kept as a record, not deleted.
- `wontfix` — a confirmed finding the **user** explicitly declined. Reserved for that — it is NOT how
  pre-existing findings are represented.

**Pre-existing vs introduced is `origin`, not `status`.** A `pre-existing` finding stays `confirmed`
(it's real and reported); downstream `fix-findings` filters on `origin: introduced`, so pre-existing
is reported but never auto-fixed without ever needing a special status.

---

## Fingerprint — semantic, not code-text

```
fingerprint = hash(file + scope + issue_kind + subject)
```

- **`dimension` is deliberately NOT in the fingerprint.** One defect seen by several dimensions
  (`structural` + `architecture` + `codex` all flag the same wrapper) is one finding — identity must
  not depend on which reviewer reported it or at what severity, or reappearance/no-progress would flip
  between cycles. Dimensions are recorded as metadata (`contributing_dimensions`), not identity.
- `issue_kind` — normalized category of the problem (e.g. `missing-error-handling`,
  `nplus1-query`, `loop-var-naming`), not the free-text summary.
- `subject` — the stable thing the finding is about (symbol/identifier/contract), not its line.
- **`snippet_hash` is NOT part of identity** — it lives in `evidence` only. A failed fix changes the
  snippet but leaves the bug, so a code-text identity would miss the reappearance; a successful fix
  removes the bug, so the semantic key stops matching. That is exactly the behaviour the rails need.
- `scope` falls back (module / top-level / config-key / test-name / md-heading) when there is no
  enclosing symbol, so script and config findings still get a stable key.
- **Normalize before hashing.** The orchestrator (sole writer) derives `issue_kind` (a kebab-case
  category, e.g. `missing-error-handling`, `nplus1-query`, `loop-var-naming`) and `subject` (the bare
  symbol/identifier) from the reviewer's record — it does not trust each reviewer to invent them
  consistently — so the same defect from two reviewers hashes to one fingerprint.

---

## Store location + keying

- Central dir under `~/.claude/` (machine-local; persists across sessions).
- **One snapshot per review session**, keyed by a stable
  `review_session_id = repo + base_sha + initial_head_sha + worktree-path`. The id is **frozen at
  cycle 1** and does NOT change as the loop's commits advance HEAD — this is what lets later cycles
  dedupe + detect reappearance against prior findings (keying on the moving `head_sha` would spawn a
  new snapshot every cycle and lose history).
- Each finding still records the `head_sha` of the cycle that observed it (the moving head), separate
  from the frozen `initial_head_sha` in the session id.
- A **current-session pointer** per repo records the active snapshot so a later session (fix tomorrow)
  resolves the right one.
- The snapshot records **`reviewers_enabled`**: the participant set that ran (the dimensions, plus
  `codex` when its MCP was present) and, when `--reviewers` was given, the resolved model per
  participant ([`reviewer-models.md`](reviewer-models.md)). A resumed run therefore reproduces the same
  reviewers on the same models rather than silently reverting to the defaults.

### Per-cycle ledger

The snapshot holds an append-only ledger, one entry per loop cycle, so the rails are determinable:

| Field | Notes |
|---|---|
| `cycle_id` | incrementing cycle number |
| `head_sha` | HEAD at the start of this cycle (moves as fixes commit) |
| `observed_fingerprints` | every fingerprint this cycle's review surfaced |
| `confirmed_introduced` | fingerprints confirmed + introduced + above floor this cycle |
| `fixed_this_cycle` | fingerprints fix-findings marked `fixed` this cycle |
| `verified_absent` | fingerprints fixed in a prior cycle that this cycle's review did NOT surface |

### Cross-session resume

On resume, compare current `HEAD` to the latest ledger entry's `head_sha`. If it advanced **outside**
the loop (someone else committed), do not silently continue — surface the drift and require an explicit
choice: resume the session, or start a fresh one. HEAD advancing *because of the loop's own commits* is
expected and not drift.

## Run metadata — failed reviewers

A reviewer that errors or returns nothing is recorded as run metadata (`reviewer`, `error`,
`cycle_id`), **not** as a finding. An empty reviewer is a fact about the reviewer, never proof of clean
code — never silently drop it.

---

## Write discipline — the orchestrator is the sole writer

- Reviewer / fixer / verifier subagents **return** structured results to the orchestrator; they
  **never** write the store. The single-threaded orchestrator serializes all writes — **no locks, no
  event-sourcing** needed.
- `deep-review`: orchestrator writes `candidate`s, then promotes survivors to `confirmed` /
  `not_reproduced` after verify.
- `fix-findings`: fixer subagents return results; the orchestrator updates `status` and writes commits.
- One writer ⇒ single source of truth, no partial-record corruption.

---

## Origin (introduced vs pre-existing)

- Capture the merge-base **once at run start** (`base_sha`); compute origin and re-review against that
  **frozen** base every cycle — never the moving per-cycle diff (else the loop's own fixes flip a
  finding's origin).
- `introduced` requires an `origin_reason` from the enum + supporting `evidence` — not merely "a line
  was added".
- The loop **auto-fixes `introduced` only**; `pre-existing` are stored + reported, remain `confirmed`
  (NOT `wontfix` — that is reserved for explicit user decline), and are filtered out by `fix-findings`'
  `origin: introduced` selection, so they are never auto-fixed (honours surgical-changes).

---

## Dedup

A single pass **before** verify, since the fingerprint already excludes `dimension`: cluster every
candidate by fingerprint (`file + scope + issue_kind + subject`), keeping all members' `evidence`. A
defect seen through several lenses (a pass-through wrapper flagged by `structural` + `architecture` +
`codex`) lands in one cluster automatically. For the merged finding, set `severity` to the **highest**
among members, `contributing_dimensions` to the sorted set, and the display `dimension` to the
highest-severity contributor (ties alphabetical — deterministic).

Verify the **merged cluster**, not a lone representative. Genuinely distinct issues differ in
`issue_kind` or `subject`, so they keep separate fingerprints — don't force-collapse them to save tokens.

---

## Reappearance + no-progress (loop rails)

Both are computed from the **per-cycle ledger**, on **fingerprints**, never line numbers.

- **Reappearance** — a fingerprint in this cycle's `confirmed_introduced` that appears in any prior
  cycle's `fixed_this_cycle` (i.e. it was fixed, the next review found it absent, and now it's back) →
  the fix didn't hold → stop + escalate.
- **No-progress** — this cycle resolved no above-floor fingerprint (`fixed_this_cycle` empty) AND
  reduced no above-floor severity, excluding fingerprints newly observed this cycle that are
  `pre-existing` → stop + escalate.
