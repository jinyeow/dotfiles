# Review Dimensions — registry + charters

The dimension registry for `deep-review`. Each row is dispatched as a **parallel reviewer subagent**
(via Task) with the charter below. All reviewers emit findings in the schema in
[`findings-schema.md`](findings-schema.md) and judge against the bar in
[`review-rubric.md`](review-rubric.md). The linter + test suite are deterministic **gates**, not
reviewers.

---

## Registry

| # | Dimension | Reads beyond diff? | Default `fix_verification` | Rubric slice |
|---|---|---|---|---|
| 1 | `correctness` | no | `test` | Layer 1 error-handling; Layer 2 #4 |
| 2 | `security` | yes (callers/config) | `test` / `manual-static` | CRITICAL security |
| 3 | `performance` | no | `manual-static` | Layer 2 #7 |
| 4 | `structural` | no (diff-local) | `manual-static` | Layer 2 #1–#5 |
| 5 | `architecture` | yes (cross-system) | `manual-static` | Layer 2 #6 (canonical layer + reuse) |
| 6 | `conventions` | no | `lint` / `manual-static` | Layer 1 (AGENTS.md conformance) |
| 7 | `tests` | no | `test` | Layer 1 testing / TDD |

**`codex`** (conditional 8th) — a cross-model reviewer over the **full** rubric, included
automatically when the `codex` MCP is present (documented exception to the offer-first rule in
`claude/CLAUDE.md`). Not a fixed dimension: a parallel second opinion emitting the same schema,
deduped with the rest. Recorded in the snapshot's `reviewers_enabled` for reproducible resume.

---

## Charters

Each charter is the reviewer's brief. Borrowed-prompt references are starting points to fold in, not
runtime dependencies.

### correctness
Logic errors, unhandled edge cases, error-handling gaps (silent ignores, catch-all hiding root cause,
missing path-exists checks, fallbacks not requested, external calls without retry-then-raise),
regressions. Reports the **actual behavioural bug** — a missing *test* for it belongs to `tests`.
Borrowed: wshobson `code-reviewer`.

### security
Injection, authz/authn gaps, secret exposure, unsafe crypto, OData/SQL escaping. Reads callers +
config to confirm exploitability. Borrowed: wshobson `security-auditor`; the built-in
`/security-review` may seed candidates.

### performance
Hot-path cost, N+1, algorithmic complexity, leaks, avoidable serialization of independent work
(rubric Layer 2 #7). No micro-optimization. Borrowed: wshobson `performance-engineer`.

### structural
**Diff-local** code-judo (rubric Layer 2 #1–#5): collapse branches, delete helpers, 1k-line smell,
spaghetti growth, thin pass-through wrappers, magic behaviour, unnecessary optionality/casts.
Operates on the diff + immediate neighbours. Cross-boundary optionality and API shape belong to
`architecture`, not here. Prefer "delete this layer" remedies.

### architecture
Cross-system fit: layering / dependency direction, module ownership, coupling/cohesion, pattern
consistency, cross-boundary optionality + API shape. **Owns rubric Layer 2 #6** — feature logic
leaking into shared paths; bespoke one-offs where a canonical utility exists; push code toward the
module that owns the concept. Reads beyond the diff (slower / costlier — accepted). Borrowed:
wshobson `architect-reviewer`.

### conventions
Conformance to `~/.claude/AGENTS.md` (rubric Layer 1): surgical-changes, strict typing, imports at
top, DRY, no silent flag/mode params, doc-with-change, commit style. Includes the PowerShell
`foreach ($singular in $plural)` semantic residue the deterministic lint gate can't decide.

### tests
Reports **missing or weak tests only** (coverage ROI, behavioural-vs-brittle — mock-invocation
assertions where a result assertion would prove behaviour, missing edge-case tests). A finding here
whose root is an actual bug links to / dedups under `correctness`. Test-dimension fixes are validated
by the suite passing (the change *is* test code, so no separate RED step). Borrowed: HAMY
test-quality prompt.

---

## Subset filtering

The registry is data-driven, so running a subset is a one-line filter. Exposing that as an arg is a
flag/mode decision to **raise with the user** per AGENTS.md — not built (YAGNI).
