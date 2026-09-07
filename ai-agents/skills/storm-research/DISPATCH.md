# Parallel-lens dispatch — runtime-neutral contract

How `storm-research` launches its two batches of parallel children — the five expert
lenses in Phase 1, and the citation verifiers in Phase 4b — on whichever runtime is
hosting the session. Unlike `deep-review` (`../deep-review/DISPATCH.md`), this skill needs
no per-child tool scoping: every lens and every verifier shares the same job (real web
research plus a text reply), so the only requirement is a distinct `task`/prompt per
child, dispatched together so they run concurrently.

## Claude Code

Spawn five `general-purpose` `Agent` tool calls in a single message, one per lens prompt.
This is the mechanism the skill originally shipped with under `claude/skills/storm-research/`;
no change from prior behavior. Phase 4b uses the same shape, one call per citation cluster.

## Pi (`pi-subagents`)

At the pinned `pi-subagents@0.60.0` the top-level `tasks: [...]` array no longer exists: the
package removed it at 0.41.0 in favor of `workflowScript` as the sole public multi-agent
orchestration surface (confirmed in the package's own `CHANGELOG.md` and in
`src/extension/schemas.ts`, whose public call schema carries no `tasks` field). Call the
`subagent` tool once, with a `workflowScript` that fans out all five lens prompts through
`runs.all`:

```js
subagent({ workflowScript: `
  return runs.all([
    { key: "lens-1", agent: "researcher", task: "<lens prompt>", output: false },
    { key: "lens-2", agent: "researcher", task: "<lens prompt>", output: false },
    ...
  ]);
` })
```

Use the builtin `researcher` agent, not a new custom agent definition. `researcher` already
ships with `tools: read, write, web_search, fetch_content, get_search_content, intercom`
(`pi-subagents`' own `agents/researcher.md`) — exactly what a lens or a verifier needs, and
those web tools require `pi-web-access` to be installed, which is pinned alongside
`pi-subagents` in `pi/settings.json`. `runs.all` items do not require distinct `agent` values,
only distinct `key` and `task` values, so one reusable agent invoked five times is sufficient —
matching this skill's "no per-child tool scoping" requirement exactly. `runs.all` resolves to
an ordered array, not a key map, so read results by index or `.map(...)`, not by key.

`researcher`'s frontmatter defaults to `output: research.md`. Since five lenses run in
parallel and this skill wants each brief returned as text, not written to a shared file,
override `output: false` on every `runs.all` item to disable that per-agent default and rely on
`outputMode`'s `"inline"` default (`pi-subagents`' sole-writer invariant: children return
text, the orchestrator is the only writer — same invariant `../deep-review/DISPATCH.md`
documents for its own children). `output` is a recognized per-item execution param at this
version (`src/workflows/scripted-workflow.ts`'s `AUTO_RESUME_PARAM_KEYS` lists it alongside
`outputMode`), so the override still applies. Phase 4b's citation verifiers use the identical
shape, one `runs.all` item per citation cluster.

**Verification status**: the `workflowScript`/`runs.all` call shape above is confirmed against
the pinned `pi-subagents@0.60.0` package's own shipped source (`src/extension/schemas.ts`,
`src/workflows/scripted-workflow.ts`) and its `docs/workflows.md` (worked examples using
exactly this shape) — this is the on-disk artifact actually installed in this repo's dev
environment, not a summary of upstream docs. It has **not** been exercised as a live smoke
test end-to-end: a direct `pi -p` probe against the only authenticated provider available at
authoring time (`openai-codex`, OAuth) returned `Codex error: The usage limit has been reached`
for every model and every prompt tried, including a bare `--no-tools` call, while `pi auth
check --provider openai-codex` reported `{"status": "ready"}` — an account-wide usage-limit
block, not a credentials problem, and not specific to `pi-subagents` or to this skill. Retry
the smoke test (call `subagent` with a `workflowScript` containing 2+ distinct-prompt
`runs.all` entries) once the limit clears before relying on this skill for a real run; see
`pi/README.md`.

## Codex CLI

Not researched. Out of scope for this skill's current migration (dotfiles issue #172) —
`storm-research`'s own portability note previously named Claude Code's `Agent` tool as a
hard dependency, and Codex's Multi-Agent v2 runtime dispatches via `[agents.<name>]` tables
in `codex/config.toml` (`ai-agents/AGENTS.md`, "Subagent Orchestration") in principle, but
whether it supports N children with N distinct prompts in one dispatch call has not been
independently verified against Codex primary docs. Mark this **unknown** pending a dedicated
check, if a Codex migration is ever in scope.
