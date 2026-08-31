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
pinned `pi-subagents@0.60.0` (`RunnerSubagentStep.tools?: string[]`, shipped source,
`package/src/runs/shared/parallel-utils.ts:44`; also `agent-serializer.ts:11,67-72`). A dimension
with `no` in "Reads beyond diff?" gets `tools: read, grep`; one with `yes` gets
`tools: read, grep, glob`. Never include `bash`, `edit`, or `write` — a reviewer that needs to
mutate anything is out of contract.

### Codex CLI

**Per-role `sandbox_mode`/`mcp_servers`/`developer_instructions` are NOT supported at the
pinned codex-cli 0.147.0.** codex-rs's `config.schema.json` defines `AgentRoleToml` with
`additionalProperties: false` limited to `config_file`, `description`, and
`nickname_candidates` (confirmed in `agent_roles.rs`'s `AgentRoleConfig`, same three
fields). An `[agents.<name>]` table carrying those other keys parses without error, but
the values are silently dropped — there is no per-role read-only sandbox, no per-role
charter injection, and no per-role MCP scoping. The finer read/grep-vs-read/grep/glob
distinction `dimensions.md`'s "reads beyond diff?" column implies has no Codex
equivalent either — record this as a known gap rather than fabricating one. Scoping in
practice is coarse: the orchestrating session's own top-level `sandbox_mode` in
`codex/config.toml` is the only enforcement that actually applies to every spawned
child, reviewer or fixer alike.

**Custom agent definitions live as `[agents.<name>]` tables in `codex/config.toml`**
(installed to `~/.codex/config.toml`), one per dimension — see that file for the full
entries, e.g. `[agents.review_correctness]`:

```toml
[agents.review_correctness]
description = """
... Read-only reviewer: apply the `correctness` charter from
~/.codex/skills/_shared/dimensions.md and the review-rubric.md bar; report findings
only, never edit, write, or run commands that mutate state.
"""
```

The read-only/report-only intent is carried in `description` — model-visible spawn
guidance the model can choose to follow, not a runtime-enforced sandbox — because
`sandbox_mode`/`developer_instructions` under `[agents.<name>]` don't reach the runtime
at this version (see above). `description` reaching spawn-tool guidance is the one
per-role customization channel confirmed to work; `config_file` ("path to a
role-specific config layer") is the schema-documented alternative, but whether a
`config_file` layer honors `sandbox_mode`/`developer_instructions` at spawn time is
unverified — do not claim it does without checking. `fix-findings`' fixer role is the
one asymmetric case: it needs write access, and its `[agents.fixer]` description says so,
but that too is guidance, not enforcement — the fixer's actual write access comes from
the orchestrating session's own top-level `sandbox_mode = "workspace-write"`.

`quick-review` dispatches a single folded reviewer carrying all three of `correctness`,
`conventions`, and `tests` (never a third participant — see `quick-review/SKILL.md`), so
its Codex agent is `[agents.review_folded]` in `codex/config.toml`, not the three separate
per-dimension entries above. `deep-review` uses the seven separate `review_<dimension>`
agents instead, one per dimension.

Dispatch a dimension by prompting the orchestrating Codex session to call its built-in
`spawn_agent` tool with `agent_type: "review_<dimension>"` (referencing the config-defined
name above) and the diff/cluster as the task. `spawn_agent` is `multi_agent`'s native
tool surface, not a CLI flag — see "Confirmed smoke test" below for the exact
end-to-end shape. `fix-findings` dispatches the same way on a Codex host: for each
fix-unit, prompt the orchestrating session to call `spawn_agent` with `agent_type:
"fixer"` (`[agents.fixer]` in `codex/config.toml`) and the fix-unit's findings/files as
the task — same mechanism, no per-role sandbox beyond what the section above already
covers.

**Correction to the #93 research report's paraphrase:** that report (based on a
summarizing WebFetch of vendor docs, not primary source — see its own caveat at
lines 69-75) described custom agents as standalone TOML files under `~/.codex/agents/`
or project-scoped `.codex/agents/`. Live-tested against the pinned install
(codex-cli 0.147.0, see below): a file dropped at `<CODEX_HOME>/agents/probe-agent.toml`
did **not** surface in `codex debug prompt-input`'s model-visible output, while a
`[agents.<name>]` table passed via `-c` (equivalent to a `config.toml` table) was
accepted by `--strict-config` and successfully referenced as `agent_type` in a live
`codex exec` call. Treat the `config.toml`-table mechanism above as the confirmed
name-resolution path; treat a separate `.codex/agents/*.toml` file format as unconfirmed
at this version. Note what this live test does and does not prove: `--strict-config`
accepting the table is not evidence its `sandbox_mode`/`developer_instructions`/
`mcp_servers` fields are honored — the same flag also accepts a wholly bogus field name
under `[agents.<name>]`, because it only validates top-level config keys. What the test
confirmed is narrower: the table's **name** resolves as `agent_type` for `spawn_agent`.
Whether the role's other fields apply anything at spawn is answered by the schema, not
by this test — see the "Per-role `sandbox_mode`/`mcp_servers`/`developer_instructions`
are NOT supported" note above.

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

At the pinned `pi-subagents@0.60.0`, two shapes exist for launching several children: an ad-hoc
multi-call in one turn (repeated single-child `subagent({ agent, task })` calls), and the
scripted `runs.all`/`workflowScript` batch API. As of 0.41.0, the package removed the older
top-level `tasks: [...]` array shape entirely — `workflowScript` is now the only way to batch
children in a single tool call — but ad-hoc multi-call was never affected by that removal, since
it never used `tasks[]`. **This skill uses ad-hoc multi-call**, matching what `council` already
exercises in practice (`council`'s `CRITIQUE` step: "Launch all charter seats as fresh isolated
workers, together when parallel dispatch is available" — no scripted workflow). Rationale:

- Consistency — `deep-review`/`quick-review` compose with `council`'s contract; diverging to a
  scripted API for one skill and ad-hoc for the rest adds a second dispatch idiom for no
  functional gain.
- Evidence asymmetry no longer applies at the current pin — the `tools:` scoping field, the
  parallel-batch mechanism, and the `runs.all()` call-site spelling (`docs/workflows.md:38,88-92`
  at the pinned 0.60.0) are all now confirmed directly in the pinned version's own shipped
  source and docs, not inferred from a newer version. Ad-hoc multi-call remains the choice for
  the consistency reason above, not because the scripted shape is unverified.

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

This is **conventional, not structurally enforced, for the read-only dimension roles**:
the per-role `sandbox_mode = "read-only"` these tables used to carry is one of the keys
`AgentRoleToml` silently drops at codex-cli 0.147.0 (see the Codex CLI section above), so
a `review_<dimension>` spawn does not run under a role-level read-only sandbox. The only
sandbox actually in effect for any spawned child, reviewer or fixer, is the orchestrating
session's own top-level `sandbox_mode` in `codex/config.toml`. If that top-level mode is
`workspace-write` (the standalone posture), a reviewer child is not physically prevented
from writing — its read-only posture rests on the `description` guidance and the model
following it, not on the runtime.

The one asymmetric case is `fix-findings`' `fixer` role, which needs write access to
apply fixes; its `description` says so, but that access — like the reviewers'
restriction — comes from the orchestrating session's own top-level `sandbox_mode`, not
from a per-role setting. When that top-level mode is `workspace-write`, writes are
confined to the session's workspace root plus any directory added via `--add-dir`; the
findings store lives under `~/.codex/` (`findings-schema.md`: "central dir under the
runtime's own config home"), outside the workspace root for any review target repo.
Live-tested (codex-cli 0.147.0, Windows): a `workspace-write` session with no
`--add-dir` was denied writing a probe file under `%USERPROFILE%\.codex\` —
`rejected: blocked by policy`. Given the #34961 root cause documented below — on this
host `workspace-write` never genuinely engages for `codex exec`/`codex sandbox` at all,
so every write is denied regardless of `--add-dir` — this denial cannot be told apart
from that host-level bug: whether it reflects real per-path scoping or is just another
instance of "everything is effectively read-only" is unverified on Windows. So the
findings-store invariant holding for the fixer as long as the orchestrator never passes
`--add-dir` covering `~/.codex/` (or wherever `$CODEX_HOME` resolves) remains an
untested assumption, not a confirmed conclusion — retest on Linux/macOS before relying
on it; still avoid passing that `--add-dir` in the meantime as a precaution.

**Open gap — orchestrator's own write path to the store is unconfirmed.** The orchestrating
Codex session runs under the same top-level `sandbox_mode = "workspace-write"`
(`codex/config.toml`), and the same live test above shows that mode denies writes under
`~/.codex/` without `--add-dir`. Nothing in this skill currently grants the orchestrator
`--add-dir` covering `~/.codex/`, so as documented today it is unclear how the orchestrator
itself writes the findings store on a Codex host — the "never `--add-dir`" advice above,
taken literally, would block the orchestrator's own write, not just the fixer's. A candidate
fix — scoping `--add-dir` to just the store's subpath rather than all of `~/.codex/` — could
not be exercised: a probe attempt (codex-cli 0.147.0, Windows, 2026-08-12) never reached a
usable `workspace-write` session to test it against. `codex exec -s workspace-write -c
approval_policy=never --add-dir "<store-subdir>" "…write a probe file into <store-subdir>…"`,
run from an unrelated cwd, reported `sandbox: read-only` in its own banner and failed with
`patch rejected: writing is blocked by read-only sandbox; rejected by user approval settings`
— the same denial appeared for a write inside the session's own workspace root and for the
no-`--add-dir` negative control, and swapping in `-c sandbox_mode=workspace-write` or
`--approve-for-me` made no difference. Escalating to the sandbox primitive directly,
bypassing the model and approval layers (`codex sandbox -c sandbox_mode=workspace-write --
powershell -NoProfile -Command "Set-Content -Path probe.txt -Value ok"`, run from the
workspace root), was denied the same way (`UnauthorizedAccessException`), so on this host
`workspace-write` itself does not engage for `codex exec`/`codex sandbox`, independent of
`--add-dir` — this is a different, host-level failure mode than the fixer's already-confirmed
"blocked by policy" denial above, not a like-for-like negative control on the same
mechanism. The `--add-dir`-scoping candidate therefore remains untested rather than
disproven; retest on a host where `codex exec -s workspace-write` demonstrably grants writes
within its own workspace before drawing a conclusion. Treat this as an open implementation
gap, not a confirmed-working path, until a live orchestrator write against the real store
location is exercised.

**Root cause identified (2026-08-13): this is a known upstream bug, not a local
misconfiguration.** Re-ran the same probe shape (`codex exec`, `codex -s workspace-write
exec`, and `-c sandbox_mode="workspace-write"`, each against both a scratch `CODEX_HOME`
and the real one) — every variant still reported `sandbox: read-only` in its own banner
and denied the write, matching the 2026-08-12 result exactly. `codex doctor` on the same
host reports a healthy `restricted fs + restricted network` sandbox for normal
interactive use, so the host's sandbox plumbing itself is not broken — only `codex
exec`'s (and `codex sandbox`'s) workspace-write path is. Found the open upstream report
matching this exactly: **[openai/codex#34961](https://github.com/openai/codex/issues/34961)**,
"Windows: `codex exec --sandbox workspace-write` remains read-only" (filed 2026-07-23,
labels `bug`/`windows-os`/`sandbox`/`exec`, still open as of 2026-08-13, no fix landed).
Its repro is the same shape as ours: `workspace-write` requested, host process launches
directly (no external sandbox wrapper), exits 0, but the effective inner sandbox stays
read-only and the expected file is never created. Consequence for this skill: **the
config_file per-role discriminating test (spawn a `sandbox_mode = "read-only"` role
against a `sandbox_mode = "workspace-write"` role and diff their write outcomes) cannot
be run on Windows at all** — there is no working `workspace-write` baseline on this
platform to compare a role's write against, so a role-level write denial and a
host-level write denial are indistinguishable here. Retest on Linux or macOS, where
`workspace-write` is not known to be broken for `codex exec`, before concluding either
way whether `config_file` honors per-role `sandbox_mode`.

## Sole-writer invariant under Pi

`findings-schema.md` requires reviewer/verifier/fixer workers to **return** results — never
write the store themselves. Under Pi, a child's `outputMode` defaults to `"inline"`
(`package/src/shared/settings.ts:387` at the pinned 0.60.0: `task.outputMode ?? config.outputMode
?? "inline"`), meaning the child's result resolves back to the caller as text rather than being
written to a file by the child. This holds the invariant by default — the orchestrator stays
the sole writer as long as dispatch never sets `outputMode: "file-only"` and no project/user
`subagents` config sets a global `outputMode: "file-only"` default (the added
`config.outputMode` term at this version); this repo's `pi/settings.json` sets no such config.
Do not set it for reviewer, verifier, or fixer children.
