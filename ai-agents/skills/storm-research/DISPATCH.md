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

Call the `subagent` tool once, with all five lens prompts as entries in its `tasks` array:

```js
subagent({ tasks: [
  { agent: "researcher", task: "<lens prompt>", output: false },
  { agent: "researcher", task: "<lens prompt>", output: false },
  ...
] })
```

Use the builtin `researcher` agent, not a new custom agent definition. `researcher` already
ships with `tools: read, write, web_search, fetch_content, get_search_content, intercom`
(`pi-subagents`' own `agents/researcher.md`) — exactly what a lens or a verifier needs, and
those web tools require `pi-web-access` to be installed, which is pinned alongside
`pi-subagents` in `pi/settings.json`. `tasks` does not require distinct `agent` values, only
distinct `task` values, so one reusable agent invoked five times is sufficient — matching
this skill's "no per-child tool scoping" requirement exactly.

`researcher`'s frontmatter defaults to `output: research.md`. Since five lenses run in
parallel and this skill wants each brief returned as text, not written to a shared file,
override `output: false` on every task entry to disable that per-agent default and rely on
`outputMode`'s `"inline"` default (`pi-subagents`' sole-writer invariant: children return
text, the orchestrator is the only writer — same invariant `../deep-review/DISPATCH.md`
documents for its own children). Phase 4b's citation verifiers use the identical shape, one
`tasks` entry per citation cluster.

**Verification status**: the `tasks` call shape above is confirmed against the pinned
`pi-subagents@0.40.0` package's own shipped `README.md` (worked examples using exactly this
shape) — this is the on-disk artifact actually installed in this repo's dev environment, not
a summary of upstream docs. It has **not** been exercised as a live smoke test end-to-end: a
direct `pi -p` probe against the only authenticated provider available at authoring time
(`openai-codex`, OAuth) returned `Codex error: The usage limit has been reached` for every
model and every prompt tried, including a bare `--no-tools` call, while `pi auth check
--provider openai-codex` reported `{"status": "ready"}` — an account-wide usage-limit block,
not a credentials problem, and not specific to `pi-subagents` or to this skill. Retry the
smoke test (call `subagent` with 2+ distinct-prompt `tasks` entries) once the limit clears
before relying on this skill for a real run; see `pi/README.md`.

## Codex CLI

Not researched. Out of scope for this skill's current migration (dotfiles issue #172) —
`storm-research`'s own portability note previously named Claude Code's `Agent` tool as a
hard dependency, and Codex's Multi-Agent v2 runtime dispatches via `[agents.<name>]` tables
in `codex/config.toml` (`ai-agents/AGENTS.md`, "Subagent Orchestration") in principle, but
whether it supports N children with N distinct prompts in one dispatch call has not been
independently verified against Codex primary docs. Mark this **unknown** pending a dedicated
check, if a Codex migration is ever in scope.
