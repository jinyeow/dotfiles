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

Scope by `sandbox_mode` on the custom agent, not a named-tool allowlist (coarser grain).
Every dimension below sets `sandbox_mode = "read-only"`; `mcp_servers = []` for all of
them — no MCP server currently registered in this repo's `codex/config.toml` supplies
anything a reviewer needs (filesystem read/grep is native, not MCP-mediated), so the
explicit decision is "none," not an unconsidered default. The finer read/grep-vs-
read/grep/glob distinction `dimensions.md`'s "reads beyond diff?" column implies has no
Codex equivalent — record this as a known gap rather than fabricating one.

**Custom agent definitions live as `[agents.<name>]` tables in `codex/config.toml`**
(installed to `~/.codex/config.toml`), one per dimension — see that file for the full
entries, e.g. `[agents.review_correctness]`:

```toml
[agents.review_correctness]
sandbox_mode = "read-only"
mcp_servers = []
# developer_instructions: the correctness charter + rubric bar, see codex/config.toml
```

`developer_instructions` points at the projected `_shared/` charter files rather than
inlining charter text, so the charter has one source (`dimensions.md`) — the same
DRY reason `quick-review`/`deep-review` already reference `_shared/` by path instead of
copying it. `fix-findings`' fixer role is the one asymmetric case: it needs write access,
so it gets its own `[agents.fixer]` entry with `sandbox_mode = "workspace-write"` instead
of `read-only`.

`quick-review` dispatches a single folded reviewer carrying all three of `correctness`,
`conventions`, and `tests` (never a third participant — see `quick-review/SKILL.md`), so
its Codex agent is `[agents.review_folded]` in `codex/config.toml`, not the three separate
per-dimension entries above. `deep-review` uses the seven separate `review_<dimension>`
agents instead, one per dimension.

Dispatch a dimension by prompting the orchestrating Codex session to call its built-in
`spawn_agent` tool with `agent_type: "review_<dimension>"` (referencing the config-defined
name above) and the diff/cluster as the task. `spawn_agent` is `multi_agent`'s native
tool surface, not a CLI flag — see "Confirmed smoke test" below for the exact
end-to-end shape.

**Correction to the #93 research report's paraphrase:** that report (based on a
summarizing WebFetch of vendor docs, not primary source — see its own caveat at
lines 69-75) described custom agents as standalone TOML files under `~/.codex/agents/`
or project-scoped `.codex/agents/`. Live-tested against the pinned install
(codex-cli 0.147.0, see below): a file dropped at `<CODEX_HOME>/agents/probe-agent.toml`
did **not** surface in `codex debug prompt-input`'s model-visible output, while a
`[agents.<name>]` table passed via `-c` (equivalent to a `config.toml` table) was
accepted by `--strict-config` and successfully referenced as `agent_type` in a live
`codex exec` call. Treat the `config.toml`-table mechanism above as the confirmed one;
treat a separate `.codex/agents/*.toml` file format as unconfirmed at this version.

### Confirmed smoke test (codex-cli 0.147.0)

See `codex/README.md`'s "Skills" section for the full command, JSON-event evidence, and
version record — not restated here. Result in short: the primary thread's `--json` event
stream resolves each child as a `collab_tool_call` (`tool: "wait"`) item, then a single
`item.completed` `agent_message` carries the combined result; no child output reaches
stdout directly. Not exercised: the full `quick-review`/`deep-review`/`review-fix-loop`/
`fix-findings` skill bodies end-to-end (this smoke test proves the dispatch primitive, not
the skills' complete pipelines).

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

## Sole-writer invariant under Codex

`findings-schema.md` requires reviewer/verifier/fixer workers to **return** results — never
write the store themselves. Verified live (see the smoke test above): the `--json` event
stream shows children resolve inside `collab_tool_call` (`tool: "wait"`) items and their
content surfaces only inside the **primary** thread's own `agent_message` — "the main thread
collects the subagent results into its final response" (the #93 report's phrasing) holds
exactly as described; there is no event type in the stream where a child writes anything
independently of the primary thread's own response.

This is also **structurally enforced**, not just conventional, for the read-only dimension
roles: every `review_<dimension>` agent runs `sandbox_mode = "read-only"`, under which no
filesystem write of any kind is permitted — reviewers/verifiers physically cannot write the
findings store even if a prompt tried to make them.

The one asymmetric case is `fix-findings`' `fixer` role, which needs `sandbox_mode =
"workspace-write"` to apply fixes. `workspace-write` confines writes to the session's
workspace root plus any directory added via `--add-dir`; the findings store lives under
`~/.codex/` (`findings-schema.md`: "central dir under the runtime's own config home"),
outside the workspace root for any review target repo. Live-tested (codex-cli 0.147.0,
Windows): a `workspace-write` session with no `--add-dir` was denied writing a probe file
under `%USERPROFILE%\.codex\` — `rejected: blocked by policy`. So the invariant holds for
the fixer as long as the orchestrator never passes `--add-dir` covering `~/.codex/` (or
wherever `$CODEX_HOME` resolves) — do not do that.

**Open gap — orchestrator's own write path to the store is unconfirmed.** The orchestrating
Codex session runs under the same top-level `sandbox_mode = "workspace-write"`
(`codex/config.toml`), and the same live test above shows that mode denies writes under
`~/.codex/` without `--add-dir`. Nothing in this skill currently grants the orchestrator
`--add-dir` covering `~/.codex/`, so as documented today it is unclear how the orchestrator
itself writes the findings store on a Codex host — the "never `--add-dir`" advice above,
taken literally, would block the orchestrator's own write, not just the fixer's. Candidate
fixes (e.g. scoping `--add-dir` to just the store's subpath rather than all of `~/.codex/`,
or a different writable-roots mechanism) were not tested. Treat this as an open
implementation gap, not a confirmed-working path, until a live orchestrator write against
the real store location is exercised.

## Sole-writer invariant under Pi

`findings-schema.md` requires reviewer/verifier/fixer workers to **return** results — never
write the store themselves. Under Pi, a child's `outputMode` defaults to `"inline"`
(`package/src/api/preflight.ts:398` at the pinned 0.40.0: `outputMode: input.outputMode ??
"inline"`), meaning the child's result resolves back to the caller as text rather than being
written to a file by the child. This holds the invariant by default — the orchestrator stays
the sole writer as long as dispatch never sets `outputMode: "file-only"`. Do not set it for
reviewer, verifier, or fixer children.
