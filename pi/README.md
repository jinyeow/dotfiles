# Pi

Tracked, non-secret Pi configuration and first-party resources. Install with
`setup.ps1 -Module pi` on Windows or `setup.sh -m pi` on Linux/WSL. `-Module ai-agents`
(`-m ai-agents` on Linux) runs Claude, Codex, and Pi together — a Pi failure there is
caught and does not block Claude or Codex — but `pi` remains independently invocable
on its own.

`settings.json` is authoritative for non-secret preferences and exact package references.
Each entry under `packages` pins an exact version (`npm:<name>@<version>`); Pi does not
auto-update them. To bump a pin, edit the version in `settings.json`, verify the package still
behaves as expected, then re-run `setup.ps1 -Module pi` (or `-Module ai-agents`) to project the
change. The Pi CLI itself (`@mariozechner/pi-coding-agent`) is unpinned but only installed
once — setup skips the `npm install` when `pi` is already on PATH, so later runs never update
it; bump it manually with `npm install --global @mariozechner/pi-coding-agent@latest`.
Pi credentials and session/authentication state remain in Pi's user directory and are
never copied by setup.

Extensions, prompt templates, and themes are projected as their existing whole-directory
resources. Skills are projected as individual children into `~/.pi/agent/skills/` from:

1. `ai-agents/skills/`;
2. `pi/skills/`, with Pi-native names winning collisions.

Setup converts the former repository-managed whole `skills` link only when its resolved
target is exactly this repository's `pi/skills`; unmanaged destinations and entries are
preserved.

The shared `council` skill and its four aliases are portable prompt orchestration
contracts, not an executable engine. Pi uses the pinned `pi-subagents` package as its
isolated-worker adapter. Quick mode is the default; debate is opt-in, and `--codex` fails
before dispatch on a default Pi install because no independent external adapter is
configured. The shared skill intentionally does not name package-specific tools. Exact Pi
skill invocation and package result semantics still require a smoke test against the
installed versions rather than a guessed command example.

`quick-review`, `deep-review`, `review-fix-loop`, and `fix-findings` (the review→fix skill set)
are portable too, projected here from `ai-agents/skills/` alongside `council`. `deep-review`'s
seven reviewer dimensions need something `council`'s symmetric critics don't: a distinct
read-only tool allowlist per dimension. On Pi this is expressed as each spawned child's `tools:`
frontmatter — confirmed present in the pinned `pi-subagents@0.40.0` shipped source
(`RunnerSubagentStep.tools?: string[]`) — per the (derived, not transcribed from `dimensions.md`)
mapping in `ai-agents/skills/deep-review/DISPATCH.md`. Dispatch uses ad-hoc multi-call rather
than the scripted `runs.all`/`workflowScript` API, reasoned from `council`'s unscripted
isolated-worker contract plus pinned-source evidence — not from a live Pi run driven this
session; see DISPATCH.md for the source-verified-vs-live-smoke-tested distinction behind that
choice. The
findings store's sole-writer invariant (reviewers/fixers return text, never write the store
themselves) holds under Pi because a child's `outputMode` defaults to `"inline"` at the pinned
version, confirmed in source (`package/src/api/preflight.ts`).
