---
name: fix-findings
description: Apply fixes for findings produced by quick-review or deep-review. Reads the findings store, fixes the introduced findings in parallel (partitioned so no two fixers touch the same file), runs tests and linter, and commits one fix-unit at a time. Use when asked to "fix the findings", "apply the review fixes", "fix the introduced issues", or after a review pass. Reach for it from review-fix-loop.
---

# Fix Findings

Consume the findings store, fix the `introduced` findings, commit. This skill **consumes** a snapshot
that a review skill emitted — `quick-review` (the default) or `deep-review` — and behaves identically
either way, since both write the same schema. It does not review or loop (that's `review-fix-loop`).
It is independently invocable.

Contracts: the record schema + store discipline are
[`../_shared/findings-schema.md`](../_shared/findings-schema.md); coding conventions are the
runtime's own `AGENTS.md` (`~/.claude/AGENTS.md`, `~/.codex/AGENTS.md`, or — on Pi, which has no
installed home-dir copy — the project's own root `AGENTS.md`, read directly). Read
the schema first — the partition and TDD rules below key off its fields.

## Quick start

```
/fix-findings [snapshot-path]
```

Default: the current-run snapshot for this repo (the pointer in the store). See findings-schema.md for
store location + keying.

---

## Pipeline

```
LOAD → PARTITION → FIX (parallel) → TEST → COMMIT
```

The **orchestrator** (you) is the sole writer of the store and the only one that commits. Fixer
workers **return** their results to you; they don't write the store or run git.

### Step 1 — Load

Resolve the snapshot (arg or current-session pointer). Select findings at `status: confirmed` AND
`origin: introduced` AND **at or above the floor** (default MEDIUM). Leave `pre-existing` findings
alone (reported, not fixed — fixing them violates surgical-changes); leave below-floor findings
reported but unfixed. Order the selected set **build-breakers first** (a parse/compile error fails the
lint + test gate for the whole file, so it must be fixed before any test-verified fix can run), then by
severity (CRITICAL → … → the floor).

**Done when:** the working set is the confirmed-introduced-above-floor findings, ordered build-breakers
first then by severity.

### Step 2 — Build fix-units, partition by conflict-set

1. Resolve each finding's `intended_files` (the files its fix will touch) if unset — inspect the
   finding + code.
2. Group findings that **share a root cause** into one **fix-unit** (one or more finding ids, the
   union of their `intended_files`, fixed by exactly one fixer + one commit). Every other finding is
   its own fix-unit. Do this *before* dispatch so two fixers never independently touch coupled logic.
3. Partition fix-units into batches by conflict-set: units with **disjoint** `intended_files` run in
   parallel; any unit sharing a file with another runs **serially** after it.

**Done when:** every finding belongs to exactly one fix-unit, and units are assigned to parallel
batches / the serial queue with no two concurrent fixers sharing a file.

### Step 3 — Fix (parallel within a batch)

The orchestrator marks every fix-unit in the batch `fixing` in the store **before** launching fixers
(so a crash mid-batch leaves visible state). Then dispatch one fixer worker per fix-unit in the
batch, together when parallel dispatch is available. How workers are launched per runtime is
[`../deep-review/DISPATCH.md`](../deep-review/DISPATCH.md) — on Codex, fix-unit fixers dispatch as
`agent_type: "fixer"`. Each fixer, for its unit:

1. State a one-sentence "why" (the defect being fixed / invariant enforced) before editing.
2. **TDD gate on `fix_verification`** (if a unit groups findings of mixed types, the strictest
   applies — `test` wins):
   - `test` → write the failing test first, confirm RED, then the minimal fix to GREEN. (A
     `tests`-dimension finding is itself test code — apply it and confirm the suite goes GREEN, no
     separate RED.)
   - `lint` / `manual-static` / `not-applicable` → apply the fix directly.
3. Run the linter on touched files (see [REFERENCE.md](REFERENCE.md)); fix violations the edit
   introduced before returning.
4. Return the result (files changed, test added, outcome) — do **not** commit or write the store.

After the batch returns, the orchestrator updates the store from the returned results.

**Done when:** every fix-unit in the batch has a returned result; repeat for the next batch / serial
item until all are done.

### Step 4 — Test + lint (the gate signals)

After all fixers in this invocation return, run the **full** test suite once and the **full** project
linter once over the source tree (see [REFERENCE.md](REFERENCE.md) — full-tree lint, not just touched
files; the linter runs by changed-file type even when no settings file exists). Return explicit
`suite_green` and `lint_clean` booleans to the caller (the loop reads these for its gate); `lint_clean`
uses the project-config-or-error-only threshold in REFERENCE.md, surfacing sub-threshold diagnostics as
LOW/CLEANUP findings. On failure: because fix-units touched disjoint files, attribute the break to a
unit, diagnose, fix, re-run; keep an incomplete unit at `fixing` with a note rather than marking
`fixed`.

**Done when:** the full suite is green, the full-tree lint is clean, and both signals are returned.

### Step 5 — Commit

Commit **one fix-unit at a time**, serialized by the orchestrator. A fix-unit is normally one finding;
merge findings into one commit only when they share a root cause. Stage only that unit's files.

```
fix(<Scope>): <imperative summary> [#<finding-id>]

- <file>: <what changed and why>
```

Set each committed finding to `status: fixed` (only after Step 4's gate passed and the commit landed),
and record its fingerprint in this cycle's ledger `fixed_this_cycle`. Conventional commits; no
`--no-verify`; no AI/Co-Authored-By attribution.

**Done when:** every fixed finding is committed, at `status: fixed`, and in `fixed_this_cycle`; the
store reflects reality.

---

## Notes

- **Introduced only.** Pre-existing findings are reported by `deep-review`, never auto-fixed here.
- **Model.** On Claude Code, fixers apply code (the implement arm of the loop) — dispatch on
  **Opus 4.8 / 4.7 / 4.6, or Sonnet 5 (or lower) — never Opus 5, never Fable**, for now, unless the
  user explicitly asks. The reviewer-side `--reviewers` argument does not apply here: it never
  selects a fixer model. Set the `model` param to a version that satisfies the pin — the bare `opus`
  alias resolves to the current default Opus (Opus 5 today) and therefore does **not** satisfy it.
  Other runtimes select through their own defaults — no equivalent pin is defined yet.
- **Sole writer + committer.** Fixers return results; you write the store and commit — this is what
  makes parallel fixers safe (findings-schema.md).
- **Conflict-set, not raw file count** — a finding may span files; partition on what each fix touches.
  A diff confined to one file correctly serializes all its fixers; parallelism only kicks in across
  multiple files.
- Never suppress a linter rule to pass; fix the underlying issue.
- **Codex (when an external adapter is available — its MCP, on Claude Code)** may be consulted
  read-only for a fix approach on a hard finding before editing; you apply the fix (Codex never
  edits). If unavailable, proceed on the host runtime alone — never fail.
