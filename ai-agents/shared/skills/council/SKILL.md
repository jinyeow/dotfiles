---
name: council
description: "Cost-bounded adversarial review of a non-diff artifact. Runs blind isolated critics and an isolated chair using native runtime delegation. Supports code, business, plan, and doc panels. Not for branch diffs or PRs; use the runtime's diff-review workflow."
metadata:
  author: justin
  version: "2.0.0"
---

# Council — portable adversarial review protocol

Council is a shared prompt orchestration contract, not an executable engine. The host
uses its native isolated delegation surface while following this policy exactly. Read and
paste the canonical [`critic contract`](references/critic-contract.md),
[`chair contract`](references/chair-contract.md), optional external
[`Codex charter`](references/codex-charter.md), and verbatim seat charters from
[`perspectives.md`](references/perspectives.md). Workers return text; the host is the sole
writer.

Preserve blind independent critique, checkable evidence, dissent, and separate
adjudication. Never simulate multiple seats in the host context. Redirect branch-diff and
PR targets to the runtime's diff-review workflow.

## Invocation and normalization

```text
council [code|business|plan|doc] [target]
  [--mode quick|debate] [--quick|--debate] [--seats 2..5]
  [+seat ...] [-seat ...] [--codex]
```

`--mode` is canonical. `--quick` aliases `--mode quick`; `--debate` aliases
`--mode debate`. The default mode is **quick**. Debate and external Codex participation
are always opt-in. Before dispatch, reject conflicting modes, unknown options/panels/seats,
seat counts outside **2–5**, or including and excluding the same seat. Aliases pin their
panel; a conflicting positional panel is an error. For generic `council`, infer the panel
once from the artifact's primary purpose, in this precedence order when multiple labels
apply: **plan** for a project plan, roadmap, rollout, or migration; **code** for a technical
design, ADR, API, or implementation approach; **business** for an idea, product, business
case, market, or pricing decision; **doc** for a presentation, proposal, or other document
whose communication quality is the decision focus. If no rule matches, or the primary
purpose remains ambiguous after applying precedence, ask exactly: “Which council panel
should review this: code, business, plan, or doc?” and wait. Do not infer from a filename
extension alone. If the decision cannot be inferred, ask exactly: “What decision should
this review inform?” and wait.

Inputs are the panel, readable target or inline text, decision and decision-maker,
accepted constraints, out-of-scope concerns, seat changes, and optional prior report.
Do not dispatch an unreadable target.

## Pipeline

```text
NORMALIZE → CAPABILITIES → SELECT → BRIEF → CRITIQUE
          → [DEBATE] → JUDGE → VALIDATE → REPORT
```

### CAPABILITIES

Before spending a call, record a run manifest containing the runtime, isolated-worker
support, parallel scheduling, report-write support, external-adapter availability,
degradation flags, and maximum calls. A runtime must provide fresh isolated contexts for
at least two critics and one chair. Sequential isolated calls are allowed when parallel
fan-out is unavailable, but disclose that fact. Otherwise stop with
`unsupported-capability` rather than role-playing a council.

If `--codex` is requested without a genuinely separate external adapter, fail before any
critic dispatch. A Codex host must reject `--codex` unless such an adapter provides an
independent context/provider; a same-host duplicate is not a cross-model seat.

### SELECT and budget

Select deterministically in registry order:

| Panel | Quick defaults (3) | Debate adds (4 total) |
|---|---|---|
| code | architecture, security, operability | simplicity |
| business | customer-market, unit-economics, premortem | execution |
| plan | critical-path, scope-sequencing, premortem | estimation-realism |
| doc | audience-fit, narrative-logic, hostile-reader | evidence-audit |

`--seats N` fills from the panel registry. `+seat` uses an unfilled slot or replaces the
lowest-priority unpinned default. `-seat` removes then fills from the next eligible entry
unless `--seats` lowered the count. A go/no-go decision replaces the lowest-priority
unpinned default with `contrarian`; it never grows the panel. External Codex counts as a
call, not a charter seat.

Projected calls are `seats + chair + codex` in quick mode and
`seats + seats + chair + codex` in debate mode. Reject projections above the normal hard
call cap of **12** before dispatch. One chair recovery call may exceed 12 only after a
failed or structurally inconsistent chair response and must be labelled `recovery`.
There are no replacement critics, critic retries, or research workers. State the selected
seats, replacements, mode, Codex status, and projected calls before dispatch.

### BRIEF

Create one immutable brief containing artifact text/readable paths and revision identity,
the decision and decision-maker, accepted constraints, out-of-scope items, and optional
prior-report reference. Every round-one seat receives exactly that brief.

### CRITIQUE

Launch all charter seats as fresh isolated workers, together when parallel dispatch is
available. Each worker gets only: the critic contract, immutable brief, its one verbatim
charter, and `round: 1`. Never expose another seat's output. Read-only fact checking is
allowed; record success, timeout, refusal, malformed output, or tool failure without
inventing output.

With `--codex`, send the same brief and critic return schema to the independent adapter
with the canonical full-panel [`Codex charter`](references/codex-charter.md). It
participates in round one only.

### DEBATE

Only in debate mode, make a compact digest of successful round-one critiques. Redispatch
each successful charter seat once in a fresh context with its full prior output, the
other-seat digest, the same brief and charter, the critic contract, and `round: rebuttal`.
When at least two other findings exist, require two evidence-bearing endorsements or
attacks. Failed round-one seats and external Codex receive no rebuttal. Record failures;
do not replace or retry.

### JUDGE and VALIDATE

Fewer than two successful independent charter critiques means an abort with `NO VERDICT`.
Otherwise launch one isolated chair with the chair contract, brief, run manifest, all
critiques, rebuttals, and failures. Include every requested seat in the scorecard.

Validate the required report sections and that the verdict agrees with surviving
blockers. Retry the chair once only for failure or a named structural inconsistency. If
recovery fails, stop as `aborted-chair-failure`; the host never authors a verdict.
Unverified evidence cannot support `BLOCKER × HIGH`. When all successful seats share a
provider/model, require a correlated-bias warning.

## Failure and cost accounting

Continue degraded after individual critic, rebuttal, or optional external-call failures
only when at least two charter critics succeeded. Never silently omit a requested seat.
Report planned, attempted, succeeded, failed, external, and recovery calls. Concurrency
does not alter the budget.

## Report

Prefer `.agents/council/reports/<artifact-slug>-<yyyymmdd>-<run-id>.md`, using a short
collision-resistant run ID. If appropriate and needed, add `/.agents/council/` to the
local exclude returned by `git rev-parse --git-path info/exclude`. Outside Git, without
write capability, after a write failure, or for sensitive material, emit the complete
report in chat and set persistence to `chat-only`. The approximately 80-line human body
excludes metadata.

```yaml
council:
  schema: 2
  run_id: <id>
  status: complete | degraded | aborted
  runtime: claude | codex | pi
  panel: code | business | plan | doc
  mode: quick | debate
  target: <display reference>
  decision: <one line>
  charter_seats_requested: []
  charter_seats_completed: []
  external_codex: not-requested | completed | failed | unavailable
  calls:
    planned: 0
    attempted: 0
    succeeded: 0
    failed: 0
    recovery: 0
  prior_report: null
```

Human sections: Verdict card, Scorecard, Findings, Dissent, Kill-shot questions, Open
questions, Run notes, and Cost and capability summary. Aborted reports say `NO VERDICT`
and include the reason; partial critiques must not masquerade as a completed decision.
When persisted, chat includes the verdict card, blocker/major counts, kill-shot questions,
dissent summary, cost summary, and path. Intermediate worker output stays in runtime
memory and is not separately persisted.
