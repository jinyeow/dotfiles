# Review lenses: registry and charters

The lens registry for `code-review`. Each lens runs as a fresh-context, read-only subagent with
the charter below, judges the diff against [`review-rubric.md`](review-rubric.md), and returns
findings in the shape [`findings-schema.md`](findings-schema.md) defines. The repo's own lint,
type-check and test commands run first as facts. They are gates, and no lens re-reports them.

---

## Registry

| Lens | Runs | Reads beyond diff? | Default `fix_verification` | Rubric slice |
|---|---|---|---|---|
| `standards` | always | no | `lint` / `manual-static` | Layer 1; Layer 2 #1–#5, #7; named smell baseline |
| `spec` | always (skipped when there is no spec) | the spec | `test` | none (the spec is the bar) |
| `bugs` | always | callers of changed code | `test` | Layer 1 error handling; Layer 2 #4 |
| `security` | on trigger | yes (callers, config) | `test` / `manual-static` | security impact |
| `performance` | on trigger | no | `manual-static` | Layer 2 #7 |
| `tests` | on trigger | no | `test` | Layer 1 testing (TDD) |
| `architecture` | on trigger | yes (cross-module) | `manual-static` | Layer 2 #6 |
| `pipelines` | on trigger | yes (templates, called scripts) | `manual-static` | Layer 1 error handling |
| `docs` | on trigger | the PR description, when there is one | `manual-static` | Layer 1 documentation |

`second-opinion` is the lens label for a finding that only the second-opinion model raised
(see `code-review` step 6). It states its `fix_verification` outright.

The user can ask in plain words to "run all lenses". Then every conditional lens runs.

Every lens is read-only. On Claude Code, allow only `Read`, `Grep` and `Glob`. On Pi, set
`tools: read, grep, glob` in the child's frontmatter. On Codex CLI, start it with
`agent_type: "reviewer"` (see `codex/config.toml`). There the read-only intent is spawn
guidance only, and the session's own `sandbox_mode` is what applies. A lens returns its
findings as text and never writes the store. Validators also get a shell to reproduce a claim
(see "Validation pass").

The charters below are the whole lens brief. There are no named lens or validator agent
definitions: `code-review` dispatches the same portable brief on every runtime.

---

## Always-on lenses

### Standards
Conformance to the repo's documented standards and the rubric's Layer 1, plus the Layer 2
structural moves (#1–#5 and #7, and #6 when the Architecture lens does not run). Also owns the
named smell baseline: report each smell as a judgement call ("possible Feature Envy"), never a
hard violation, and drop it where a documented repo standard endorses the pattern. Cite the
standard (file and rule) for every hard violation.

### Spec
Checks the diff against the originating issue or spec. Reports requirements that are missing or
partial, behaviour nobody asked for (scope creep), and requirements that look implemented but
are implemented wrongly. Quote the spec line for each finding.

When the spec has acceptance criteria (a linked work item or issue), the Spec lens also returns
the acceptance-criteria checklist: one row per criterion, with a verdict of `met`, `not met`,
`after merge` or `n/a`, and the evidence. Each `not met` row is also a finding, with blocking
criterion `spec`. An `after merge` row is never a finding.

- A criterion about what the code must contain or do is checked now.
- A criterion about a run, a deploy, a rollout, a notice, or work in another PR is `after
  merge`, unless its text says "before merge" or "in the PR", or names this PR. Mark work in
  another PR as `after merge` only when you can name that PR, and record it with the row. If
  the work is in neither this PR nor a PR you can name, check the criterion now.
- Split a criterion that covers both kinds of work, and give each part its own verdict.
- Changes and comments on the work item made after the last push can change what the PR must
  do. Apply them, and quote each one you rely on with its date and author.

### Bugs
Logic errors, unhandled edge cases, error-handling gaps (silent ignores, catch-alls that hide the
root cause, missing path checks, fallbacks nobody asked for, external calls without
retry-then-raise), and regressions. Reports the behavioural bug itself. A missing test for it
belongs to Tests.

---

## Conditional lenses

### Security
Trigger: the diff touches auth, secrets, crypto, input parsing, SQL or OData, infrastructure as
code, pipelines, or permissions. Looks for injection, authn and authz gaps, secret exposure,
unsafe crypto and missing escaping. Reads callers and config to confirm the finding can be
exploited. For this lens, likelihood means exploitability.

### Performance
Trigger: the diff touches queries, loops over collections, hot paths, caching, or concurrency.
Looks for N+1 queries, poor algorithmic complexity, leaks, and independent work run in series
for no reason. Skips micro-optimisations.

### Tests
Trigger: test files changed, or production code changed with no test change. Reports missing or
weak tests: no test for new behaviour or a fixed bug, missing edge cases, and mock-invocation
assertions where a result assertion would prove the behaviour. A test gap whose root is a real
bug goes to Bugs.

### Architecture
Trigger: the diff adds modules or files, adds cross-module imports, changes a public API or
interface, or changes dependencies. Checks layering, dependency direction, module ownership and
coupling. Owns rubric Layer 2 #6: feature logic leaking into shared paths, and one-off code where
a canonical helper already exists. Reads beyond the diff.

### Pipelines
Trigger: the diff touches a CI/CD definition (`.github/workflows/`, `azure-pipelines*.yml`,
pipeline templates), a deploy or release script, a schedule, or a branch policy. Checks what
runs automatically and when: triggers, conditions, schedules and path filters. Checks failure
modes (a step that fails open, or passes when its work failed), agent pools and runners,
rollout and rollback, and whether a failure is visible. Reads the templates and the scripts the
pipeline calls. Permissions and secrets in a pipeline belong to Security.

### Docs
Trigger: the diff changes a README, other docs, help text or code comments, or the PR
description or commit messages say what the change does. Checks each claim against what the
code does: a README step that fails as written, a comment that describes old behaviour, a PR
description that claims a test or a behaviour the diff lacks. A finding about a doc, a comment
or the PR description is always LOW and its disposition is `note` (see `review-rubric.md`).
A behaviour change with no doc update at all stays with Standards (rubric Layer 1).

---

## Validation pass

The validation pass runs after the lenses and the dedup. `code-review` gives each merged finding
to a separate validator: a fresh-context subagent (on Codex, `agent_type: "reviewer"`) whose job
is to refute the claim against the actual code. One validator may take a batch of 3 to 6 related
claims. The finding's own lens never validates it.

### The brief: neutral claims only

To keep the validator from anchoring on the lens, the brief holds only:

- the diff command, the head commit and the merge-base;
- the facts file from `code-review` step 4;
- the spec or acceptance-criteria text, when a claim is about it;
- each claim as three neutral fields:

```
### <claim id>
- Claim: <one or two sentences: what the code does or lacks>
- Location: <file>:<line>
- Failure scenario: <the input or event, and what the system then does>
```

Leave out the lens's likelihood, impact, severity, blocking criterion, evidence and fix. Leave
out which lens or model raised the claim, how many raised it, and any suggested verdict. Write
the claim and the scenario as facts: no severity words ("dangerous", "clearly", "breaks",
"must"), no intent ("the author expected"), no "check X" hints. For example: "Merging runs the
deploy job on every branch, because the condition tests `always()`." A tie-break validator gets
the same brief with one claim, and is never told that an earlier validator disagreed.

### What a validator does

- Checks the location first. When the code at that line differs but the issue is real, it gives
  the corrected location.
- Traces the real path: callers, conditions, defaults, error handling. It looks for the guard
  that makes the claim false.
- Reproduces where it can: the repo's tests, a snippet, a crafted input. It may run read-only
  commands for this. It changes files only in a temp copy, never in the worktree, and makes no
  writes to a live service. On Claude Code its allowlist is `Read`, `Grep`, `Glob` and `Bash`;
  on Pi, `read, grep, glob, bash`.
- Compares with the merge-base (`git show <base>:<file>`) to decide whether the change
  introduced the problem.
- Rates likelihood and impact itself, with the rubric, and decides the blocking criterion.

### Verdicts and output

| Verdict | Meaning | Result |
|---|---|---|
| `CONFIRMED` | The claim holds as stated. | `confirmed` |
| `PARTIAL` | Part of it holds; the notes say which part. | `confirmed`, restated to cover only that part |
| `REFUTED` | The claim is wrong; the notes say why. | `not_reproduced` |
| `UNVERIFIABLE` | It cannot be settled either way, for example because it needs external state. The notes say what is missing. | `unverified`, listed under Not covered |

A validator returns one block per claim, in the order given:

```
### <claim id>
- Verdict: CONFIRMED | PARTIAL | REFUTED | UNVERIFIABLE
- Location: as given | <corrected file:line>
- Likelihood: HIGH | MED | LOW (<what has to happen>)
- Impact: HIGH | MED | LOW (<what happens>)
- Blocking criterion: <a criterion from review-rubric.md> | none
- Origin: introduced | pre-existing | partly (<the part the change introduced>)
- Notes: <what it read or ran, and what that showed>
```

The validator's likelihood, impact, blocking criterion and origin are the final values.
`code-review` recomputes severity from them with the matrix; when the stated severity differs,
the matrix wins. When the lens and the validator disagree in a way that changes whether the
finding blocks, `code-review` may run one tie-break validator. It never settles the
disagreement by its own judgement. For `partly`, it restates the finding to cover the
introduced part and marks it `introduced`.
