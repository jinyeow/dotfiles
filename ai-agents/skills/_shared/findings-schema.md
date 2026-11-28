# Findings Store — schema, fingerprint, store discipline

Shared contract for the review and fix skills. `code-review` emits findings, `fix-findings`
consumes them, and `refine-until-ready` owns the loop's cycles and rail decisions. Each skill's
orchestrator owns its own status writes: `code-review` sets `candidate`, `confirmed` and
`not_reproduced` and `unverified`; `fix-findings` sets `fixing`, `fixed` and `rejected`; `refine-until-ready` sets
`parked`. Whichever skill is talking to the user records `wontfix`. The store is the seam between
the skills: each skill's input and output is explicit, and no skill reaches into another's
internals.

Quality bar and severity matrix: [`review-rubric.md`](review-rubric.md). Lenses:
[`lenses.md`](lenses.md).

---

## Record schema (JSONL, one finding per line)

| Field | Type | Notes |
|---|---|---|
| `id` | string | unique within a run |
| `fingerprint` | string | semantic identity (see below); drives dedup, reappearance and the other rails |
| `repo` | string | canonical repo id: normalized origin remote URL (stable across machines); root-path hash only as fallback |
| `base_sha` | string | frozen merge-base SHA captured at run start |
| `head_sha` | string | branch head SHA at review time (SHA, not branch name) |
| `file` | string | path relative to repo root |
| `scope` | string | enclosing symbol (function/class/block); fallback `module` / `top-level` / config-key-path / test-name / md-heading |
| `lines` | string | display only (e.g. `120-134`); never part of identity |
| `reported_location` | string \| null | the lens's `file:line` when the validator corrected it; `file`, `scope` and `lines` then hold the corrected location |
| `lens` | enum | primary lens (display only): the highest-severity contributor, ties broken alphabetically. One of `standards` \| `spec` \| `bugs` \| `security` \| `performance` \| `tests` \| `architecture` \| `pipelines` \| `docs` \| `second-opinion` |
| `contributing_lenses` | string[] | every lens that reported this defect (sorted) |
| `likelihood` | enum | `HIGH` \| `MED` \| `LOW` (see review-rubric.md) |
| `impact` | enum | `HIGH` \| `MED` \| `LOW` (see review-rubric.md) |
| `severity` | enum | `HIGH` \| `MED` \| `LOW`, derived from `likelihood` × `impact` with the rubric's matrix |
| `blocking_criterion` | enum | `severity` \| `spec` \| `convention` \| `untested-logic` \| `mode-parameter` \| `none`, from the rubric's Blocking rule; the validator decides it |
| `blocking` | bool | derived: true when `origin` is `introduced` and `blocking_criterion` is not `none` |
| `disposition` | enum \| null | `blocking` \| `deferred` \| `note` (see the rubric's Blocking rule); null unless the finding is `confirmed` and `introduced` |
| `origin` | enum | `introduced` \| `pre-existing` |
| `origin_reason` | enum | `changed_hunk` \| `new_call_path` \| `new_config_exposure` \| `new_dependency` (required when `origin=introduced`) |
| `fix_verification` | enum | `test` \| `lint` \| `manual-static` \| `not-applicable`: how the fix is validated; `test` means TDD |
| `validation_verdict` | enum \| null | `CONFIRMED` \| `PARTIAL` \| `REFUTED` \| `UNVERIFIABLE`, from the validation pass (see `lenses.md`); null while `candidate` |
| `validated` | bool | true once the validation pass confirmed the finding against the code (`CONFIRMED` or `PARTIAL`) |
| `intended_files` | string[] \| null | files the fix will touch; may be null at review time, resolved before fix-scheduling |
| `status` | enum | `candidate` \| `confirmed` \| `not_reproduced` \| `unverified` \| `fixing` \| `fixed` \| `rejected` \| `parked` \| `wontfix` |
| `status_reason` | string \| null | one line; required for `rejected`, `parked` and `wontfix` |
| `summary` | string | one-line problem statement |
| `fix_approach` | string | concrete remedy (prefer "delete X" over "rename Y") |
| `evidence` | object | `{ hunk, snippet_hash, rationale }`: why it is real; for `introduced`, why the diff caused it |

Validate every record against this schema before writing. An invalid record fails that
subagent's result and does not enter the store.

### Status lifecycle

```
candidate ──(validation confirms)──▶ confirmed ──▶ fixing ──▶ fixed
    │                                    │            │
    │                                    ├────────────┴──(fixer disputes, with reason)──▶ rejected
    │                                    ├────────────┬──(loop stops with it open)──────▶ parked
    │                                    └──(user declines or accepts the trade-off)────▶ wontfix
    ├──(validation refutes)──▶ not_reproduced
    └──(validation cannot settle it)──▶ unverified
```

- `candidate`: emitted by a lens or the second opinion and not yet validated. No finding stays
  here after validation.
- `confirmed`: the validation pass confirmed it against the code (`validated=true`).
- `not_reproduced`: the validation pass refuted it. Kept as a record, not deleted.
- `unverified`: the validator returned `UNVERIFIABLE`. Kept as a record and listed under Not
  covered in the report, with what was missing. It never blocks and is never fixed.
- `fixing` / `fixed`: `fixed` is set only after the fix's `fix_verification` passes (test green,
  lint clean or static check) and the commit lands.
- `rejected`: `fix-findings` checked the finding before or while fixing it and disputed it. The
  finding is wrong, already fixed, not worth fixing, or needs a redesign beyond the change's
  scope. `status_reason` says which.
- `parked`: `refine-until-ready` stopped on a rail with this finding still open. `status_reason`
  names the rail.
- `wontfix`: the user explicitly declined the finding, or accepted it as a documented trade-off.
  Reserved for a user decision. Pre-existing findings do not use it.

Pre-existing versus introduced is `origin`, not `status`. A `pre-existing` finding stays
`confirmed`. `fix-findings` selects only `blocking` findings, and `blocking` requires `origin:
introduced`, so a pre-existing finding is reported but never auto-fixed.

---

## Fingerprint — semantic, not code-text

```
fingerprint = hash(file + scope + issue_kind + subject)
```

- `lens` is deliberately not in the fingerprint. One defect that several lenses see (Standards,
  Architecture and the second opinion all flag the same wrapper) is one finding. Identity must
  not depend on which lens reported it or at what severity, or reappearance and oscillation would
  flip between cycles. Lenses are metadata (`contributing_lenses`).
- `issue_kind` is a normalized category of the problem (e.g. `missing-error-handling`,
  `nplus1-query`, `loop-var-naming`), not the free-text summary.
- `subject` is the stable thing the finding is about (symbol, identifier or contract), not its
  line.
- `snippet_hash` is not part of identity. It lives in `evidence` only. A failed fix changes the
  snippet but leaves the bug, so a code-text identity would miss the reappearance. A successful
  fix removes the bug, so the semantic key stops matching. The rails need exactly that.
- `scope` falls back (module, top-level, config key, test name, md heading) when there is no
  enclosing symbol, so script and config findings still get a stable key.
- Normalize before hashing. The orchestrator (sole writer) derives `issue_kind` (kebab-case) and
  `subject` (the bare symbol or identifier) from the lens's record. It does not trust each lens
  to invent them consistently, so the same defect from two lenses hashes to one fingerprint.

---

## Store location + keying

- Central dir under the runtime's own config home (`~/.claude/`, `~/.codex/`, or `~/.pi/`;
  machine-local; persists across sessions).
- One snapshot per review session, keyed by a stable
  `review_session_id = repo + base_sha + initial_head_sha + worktree-path`. The id is frozen at
  cycle 1 and does not change as the loop's commits advance HEAD. This lets later cycles dedup
  and detect reappearance against earlier findings. Keying on the moving `head_sha` would start
  a new snapshot every cycle and lose the history.
- Each finding still records the `head_sha` of the cycle that observed it (the moving head),
  separate from the frozen `initial_head_sha` in the session id.
- A current-session pointer per repo records the active snapshot, so a later session (fix
  tomorrow) resolves the right one.

### Per-cycle ledger

The snapshot holds an append-only ledger, one entry per cycle, so the rails can be computed.
A standalone `code-review` writes one entry.

| Field | Notes |
|---|---|
| `cycle_id` | incrementing cycle number |
| `head_sha` | HEAD at the start of this cycle (moves as fixes commit) |
| `reviewed_range` | the range reviewed this cycle: `<base_sha>...<head>` on cycle 1, then `<previous head>..<head>` |
| `lenses_run` | lenses that ran this cycle, plus the second-opinion model when one ran |
| `not_covered` | lenses skipped or failed, tools that could not run, `unverified` fingerprints, and `no spec` when there was none |
| `observed_fingerprints` | every fingerprint this cycle's review surfaced |
| `confirmed_introduced` | the open set after this cycle's review: fingerprints at `confirmed`, `introduced` and `blocking` |
| `fixed_this_cycle` | fingerprints `fix-findings` marked `fixed` this cycle |
| `rejected_this_cycle` | fingerprints `fix-findings` marked `rejected` this cycle |
| `verified_absent` | fingerprints fixed in an earlier cycle that this cycle's check found still absent |
| `fix_lines_added` | cumulative changed lines (added plus removed) from fix commits, across all cycles so far |

### Cross-session resume

On resume, compare the current `HEAD` to the latest ledger entry's `head_sha`. If it advanced
outside the loop (someone else committed), do not continue silently. Surface the drift and ask
the user to choose: resume the session, or start a fresh one. HEAD advancing because of the
loop's own commits is expected and is not drift.

## Run metadata: not covered

A lens that errors or returns nothing is recorded in the ledger's `not_covered`, not as a
finding. An empty lens result is a fact about the lens, never proof of clean code. Never drop it
silently.

---

## Write discipline — the orchestrator is the sole writer

- Lens, validation and fixer subagents return structured results to the orchestrator. They never
  write the store. The single-threaded orchestrator serializes all writes, so no locks and no
  event-sourcing are needed.
- `code-review`: the orchestrator writes `candidate`s, then sets each to `confirmed`,
  `not_reproduced` or `unverified` after validation.
- `fix-findings`: fixer subagents return results; the orchestrator updates `status` and makes the
  commits.
- `refine-until-ready`: the orchestrator writes the ledger's loop fields and sets `parked`.
- One writer gives a single source of truth and no partial-record corruption.

---

## Origin (introduced vs pre-existing)

- Capture the merge-base once at run start (`base_sha`). Compute origin against that frozen base
  every cycle, never against the moving per-cycle range, or the loop's own fixes would flip a
  finding's origin.
- `introduced` requires an `origin_reason` from the enum and supporting `evidence`. A line merely
  being added is not enough.
- The loop auto-fixes `introduced` blocking findings only. `pre-existing` findings are stored and
  reported, stay `confirmed` (`wontfix` is reserved for a user decision), and never block, so
  `fix-findings` never selects them. This honours surgical changes.

---

## Dedup

A single pass before validation, since the fingerprint already excludes `lens`: cluster every
candidate by fingerprint (`file + scope + issue_kind + subject`) and keep all members'
`evidence`. A defect seen through several lenses lands in one cluster. The merged finding takes
`likelihood` and `impact` from its highest-severity member (ties: the higher impact), sets
`contributing_lenses` to the sorted set, and sets the display `lens` to the highest-severity
contributor (ties alphabetical).

When the validator corrects a finding's location, record the lens's location in
`reported_location`, update `file`, `scope` and `lines`, and recompute the fingerprint. If the
new fingerprint matches another finding, merge the two.

Validate the merged cluster, not a lone member. Genuinely distinct issues differ in `issue_kind`
or `subject`, so they keep separate fingerprints. Do not force-collapse them to save tokens.

---

## Loop rails

`refine-until-ready` computes every rail from the per-cycle ledger and the store, on fingerprints,
never on line numbers. When one trips, it stops, sets each open blocking finding to `parked` with
the rail as `status_reason`, and hands back to the user.

| Rail | Trips when |
|---|---|
| cap | the cycle count reaches `--cap` (default 5) |
| scope | a fix-unit touched a file outside its findings' `intended_files`; `fix-findings` reports this instead of committing the unit |
| size budget | `fix_lines_added` exceeds 50% of the changed lines in the original diff (`<base_sha>...<initial_head_sha>`) |
| reappearance | a fingerprint in this cycle's `confirmed_introduced` appears in an earlier cycle's `fixed_this_cycle`: the fix did not hold |
| oscillation | this cycle's `confirmed_introduced` equals an earlier cycle's set, for example A open, then B, then A again |
| no progress | this cycle's `fixed_this_cycle` and `rejected_this_cycle` are both empty while blocking findings are open |
