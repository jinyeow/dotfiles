# Reviewer dispatch — runtime-neutral contract

How `quick-review` and `deep-review` launch reviewer/verifier workers on whichever runtime is
hosting the session. Reuses [`council`'s isolated-worker
contract](../council/SKILL.md) (`CAPABILITIES` + `CRITIQUE`, `../council/SKILL.md:57-64,102-106`)
as the base: record a run manifest, launch fresh isolated workers together when parallel
dispatch is available, degrade to sequential + disclose otherwise, or stop with
`unsupported-capability`. What these two skills need beyond `council` is the one thing
`council`'s symmetric read-only critics don't: **a distinct tool allowlist per reviewer
dimension** (`_shared/dimensions.md`).

## Per-dimension tool scoping

`dimensions.md` does not itself define a tool allowlist per dimension — it has no tool column.
The table below is **derived here, in #115**, not transcribed from an existing allowlist: every
reviewer dimension is read-only by the read-only reviewer contract in `findings-schema.md`
(reviewers return findings as text; they never edit, write the store, or commit — the
sole-writer invariant), so no row gets `bash`, `edit`, or `write`. The one axis `dimensions.md`
does already carry that maps onto tool scope is its "Reads beyond diff?" column: a diff-local
dimension only needs the changed files; a cross-system dimension needs repository-wide search.
This table is the allowlist source of record for dispatch until `dimensions.md` itself gains a
column for it (out of scope here — no content changes to `dimensions.md` per #115's design).

| Dimension | Reads beyond diff? | Allowlist |
|---|---|---|
| `correctness` | no | read, grep |
| `security` | yes | read, grep, glob |
| `performance` | no | read, grep |
| `structural` | no | read, grep |
| `architecture` | yes | read, grep, glob |
| `conventions` | no | read, grep |
| `tests` | no | read, grep |

Verifiers (Step 4 of `deep-review`, the adversarial refute pass) get the same allowlist as the
dimension they're verifying — verification never needs broader access than the original finding.

### Claude Code

Dispatch each dimension as an `Agent` tool call restricted to its allowlist above (named-tool
allowlist, e.g. `Read, Grep` or `Read, Grep, Glob`). This is the mechanism the skills already
use; no change from current behavior.

### Pi (`pi-subagents`)

Express the allowlist as the child agent's `tools:` frontmatter — confirmed present at the
pinned `pi-subagents@0.40.0` (`RunnerSubagentStep.tools?: string[]`, shipped source,
`package/src/runs/shared/parallel-utils.ts`; also `agent-serializer.ts:10,58-63`). A dimension
with `no` in "Reads beyond diff?" gets `tools: read, grep`; one with `yes` gets
`tools: read, grep, glob`. Never include `bash`, `edit`, or `write` — a reviewer that needs to
mutate anything is out of contract.

### Codex CLI

Scope by `sandbox_mode` on the custom agent, not a named-tool allowlist (coarser grain,
confirmed via `codex features list` on the locally installed 0.147.0 — see the #93 research
report). Every dimension above sets `sandbox_mode: read-only`; no `mcp_servers` beyond what
read-only static analysis needs. The finer read/grep-vs-read/grep/glob distinction has no
Codex equivalent yet — record this as a known gap rather than fabricating one; Codex-native
porting is ticket #116 per the migration-sequencing ADR.

## Codex as a cross-model reviewer

Independent of per-dimension scoping above: `codex` (the conditional 8th reviewer /
quick-review's second participant) is a **different runtime's model** consulted as an external
adapter, not one of the seven dimension workers.

- **On Claude Code**: call the `mcp__codex__codex` MCP tool with `approval-policy: never`,
  `sandbox: read-only`, per `reviewer-models.md`'s call shape.
- **On Codex CLI itself**: there is no external Codex adapter to call (the host *is* Codex) —
  omit this participant; `reviewers_enabled` records it as not present, same as when the MCP is
  absent under Claude.
- **On Pi**: Pi can delegate to Codex as a model backend when `defaultProvider` is configured
  for it (`pi/settings.json`); dispatch it as an ordinary isolated worker on that model rather
  than a separate adapter call, with the same read-only allowlist as any full-rubric reviewer.

## Dispatch call shape (Pi)

Two shapes exist in the pinned `pi-subagents@0.40.0` source: an ad-hoc multi-call in one turn,
and the scripted `runs.all`/`workflowScript` batch API. **This skill uses ad-hoc multi-call**,
matching what `council` already exercises in practice (`council`'s `CRITIQUE` step: "Launch all
charter seats as fresh isolated workers, together when parallel dispatch is available" — no
scripted workflow). Rationale:

- Consistency — `deep-review`/`quick-review` compose with `council`'s contract; diverging to a
  scripted API for one skill and ad-hoc for the rest adds a second dispatch idiom for no
  functional gain.
- Evidence asymmetry — the `tools:` scoping field and the parallel-batch *mechanism* are
  confirmed in the pinned 0.40.0 shipped source; the exact `runs.all()` call-site spelling is
  confirmed only against newer (0.44.0) docs, not source-verified at the pin. Ad-hoc multi-call
  avoids depending on the unverified spelling.

This is **source-verified against the pinned version, not executed as a live smoke test** — no
live Pi session was driven interactively in this session to confirm ad-hoc multi-call actually
parallelizes end-to-end (the #93 research report's local `.pi-subagents/` transcript evidence,
36ms apart, is the closest available real-run evidence, from a prior unrelated session). Treat
the call-shape choice as reasoned from primary source plus that transcript evidence, not as a
freshly executed smoke test.

## Sole-writer invariant under Pi

`findings-schema.md` requires reviewer/verifier/fixer workers to **return** results — never
write the store themselves. Under Pi, a child's `outputMode` defaults to `"inline"`
(`package/src/api/preflight.ts:398` at the pinned 0.40.0: `outputMode: input.outputMode ??
"inline"`), meaning the child's result resolves back to the caller as text rather than being
written to a file by the child. This holds the invariant by default — the orchestrator stays
the sole writer as long as dispatch never sets `outputMode: "file-only"`. Do not set it for
reviewer, verifier, or fixer children.
