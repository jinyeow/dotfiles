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

`second-opinion` is the lens label for a finding that only the second-opinion model raised
(see `code-review` step 6). It states its `fix_verification` outright.

The user can ask in plain words to "run all lenses". Then every conditional lens runs.

Every lens is read-only. On Claude Code, allow only `Read`, `Grep` and `Glob`. On Pi, set
`tools: read, grep, glob` in the child's frontmatter. On Codex CLI, start it with
`agent_type: "reviewer"` (see `codex/config.toml`). There the read-only intent is spawn
guidance only, and the session's own `sandbox_mode` is what applies. A lens returns its
findings as text and never writes the store.

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

---

## Validation pass

The validation pass runs after the lenses and the dedup. `code-review` gives each finding to a
separate read-only subagent (on Codex, `agent_type: "reviewer"`) briefed to refute it against
the actual code. It returns
`confirmed` or `not reproduced` with a one-line reason, and `not reproduced` when unsure.
Only confirmed findings are reported. It uses the same read-only tool allowlist as the lenses.
