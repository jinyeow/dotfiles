# Pi

Tracked, non-secret Pi configuration and first-party resources. Install with
`setup.ps1 -Module pi` on Windows or `setup.sh -m pi` on Linux/WSL.

`settings.json` is authoritative for non-secret preferences and exact package references.
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
