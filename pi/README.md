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
change. The Pi CLI itself (`@earendil-works/pi-coding-agent`) is unpinned but only installed
once — setup skips the `npm install` when `pi` is already on PATH, so later runs never update
it; bump it manually with `npm install --global @earendil-works/pi-coding-agent@latest`.
Pi credentials and session/authentication state remain in Pi's user directory and are
never copied by setup.

Extensions, prompt templates, and themes are projected as their existing whole-directory
resources: `setup.ps1`/`setup.sh` junction `pi/extensions/`, `pi/prompts/`, and `pi/themes/`
wholesale into `~/.pi/agent/`, so a single-file extension needs no `settings.json` entry —
`settings.json`'s `packages` array is only for `npm:<name>@<version>` pins installed via
`pi install`, not local files. `pi/extensions/git-guardrails.ts` blocks the same destructive
git commands as `claude/skills/git-guardrails-claude-code` (`git push`, `git reset --hard`,
`git clean -f`/`-fd`, `git branch -D`, `git checkout .`/`git restore .`), via Pi's
`tool_call` extension event (`pi.on("tool_call", ...)`, narrowed to the bash tool with
`isToolCallEventType("bash", event)`, blocking by returning `{ block: true, reason }`).
Its matching now quote-scrubs the command string before matching (ported from the more
refined `claude/block-destructive-vcs.ps1`, not that skill's naive `block-dangerous-git.sh`)
so a destructive phrase quoted inside e.g. a commit message doesn't false-block, and
`git stash push` is excluded from the push pattern by name.

`pi/extensions/project-brain-autoload.ts` injects the active project-brain initiative's
`core.md` + `STATUS.md` once per session, mirroring Claude Code's and Codex's own
SessionStart hooks (#186). It uses Pi's `before_agent_start` extension event (the only one
that can return a message into the conversation — `session_start` is side-effect only),
gated by a flag reset on Pi's `session_start` event so injection recurs once per session
rather than once per process. Rather than reimplementing the resolve-and-read procedure in
TypeScript, it shells out to the same
`ai-agents/skills/project-brain/scripts/session-start.ps1` the Claude Code and Codex hooks
run (projected to `~/.pi/agent/skills/project-brain/scripts/session-start.ps1`), feeding
it a SessionStart-shaped `{ cwd }` JSON payload on stdin and forwarding
`hookSpecificOutput.additionalContext` from its JSON stdout — one resolver implementation
shared across all three runtimes. The `pwsh` child runs via `-Command` with explicit
`[Console]::InputEncoding`/`OutputEncoding = [System.Text.UTF8Encoding]::new()` preambles
(not `-File` directly): PowerShell 7 falls back to the legacy OEM codepage for stdin/stdout
when spawned without an attached console (as Node's `execFile` does), which silently
mangles multi-byte characters — a non-ASCII `cwd` going in, or characters read from
`core.md`/`STATUS.md` (e.g. "→") coming back out as invalid JSON.
Scoped to this extension's own invocation only, not a `session-start.ps1` change, so
Claude Code's and Codex's hook invocations are unaffected.

Skills are projected as individual children into `~/.pi/agent/skills/` from:

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

`storm-research` (`ai-agents/skills/storm-research/`) is portable too, as of #172 resolving its
prior blocker (#95): its five expert-lens prompts (Practitioner, Academic, Skeptic, Economist,
Historian) and its citation-verifier fan-out both dispatch as parallel children with distinct
prompts and no per-child tool scoping — a lighter bar than `deep-review`'s per-dimension tool
allowlists. At the pinned `pi-subagents@0.60.0`, the top-level `tasks: [...]` call shape no
longer exists: it was removed at 0.41.0 in favor of `workflowScript` as the sole public
multi-agent orchestration surface (confirmed in the package's own `CHANGELOG.md` and in
`src/extension/schemas.ts`, whose public call schema carries no `tasks` field). Dispatch is now
`subagent({ workflowScript: "return runs.all([{ key: 'lens-1', agent: 'researcher', task: '<lens
prompt>', output: false }, ...]);" })`, reusing the builtin `researcher` agent (already carrying
`pi-web-access`'s tools) five times with distinct `task` strings rather than a new custom
agent, since this repo has no `pi/agents/` projection to discover one; `output: false`
overrides `researcher`'s default `output: research.md` so results return inline instead of
colliding on one shared file. `output` is a recognized per-item `runs.all` param at this
version (`src/workflows/scripted-workflow.ts`'s `AUTO_RESUME_PARAM_KEYS` lists it alongside
`outputMode`), so the override still applies. See `ai-agents/skills/storm-research/DISPATCH.md`
for the full per-runtime contract. This `workflowScript`/`runs.all` call shape is
source-verified against the installed `pi-subagents@0.60.0` package's own shipped source and
`docs/workflows.md`, not executed as a live smoke test: a direct `pi -p` probe against the only
authenticated provider here (`openai-codex`, OAuth) returned `Codex error: The usage limit has
been reached` for every model and every prompt tried, including a bare `--no-tools` call, while
`pi auth check --provider openai-codex` reported `{"status": "ready"}` — an account-wide
usage-limit block, not a credentials problem. Retry the smoke test (call `subagent` with a
`workflowScript` containing 2+ distinct-prompt `runs.all` entries) once the limit clears before
relying on this skill for a real run.

`quick-review`, `deep-review`, `review-fix-loop`, and `fix-findings` (the review→fix skill set)
are portable too, projected here from `ai-agents/skills/` alongside `council`. `deep-review`'s
seven reviewer dimensions need something `council`'s symmetric critics don't: a distinct
read-only tool allowlist per dimension. On Pi this is expressed as each spawned child's `tools:`
frontmatter — confirmed present in the pinned `pi-subagents@0.60.0` shipped source
(`RunnerSubagentStep.tools?: string[]`, `src/runs/shared/parallel-utils.ts`) — per the (derived,
not transcribed from `dimensions.md`) mapping in `ai-agents/skills/deep-review/DISPATCH.md`.
`tools` is an agent-definition frontmatter field, not a per-call parameter, at this version too
(there is no `tools` field on the public `subagent` tool-call schema), so the dispatch mechanism
is unaffected by 0.41.0 removing the top-level `tasks[]` call shape (see the `storm-research`
paragraph above). Dispatch uses ad-hoc multi-call rather than the scripted `runs.all`/
`workflowScript` API, reasoned from `council`'s unscripted isolated-worker contract plus
pinned-source evidence — not from a live Pi run driven this session; see DISPATCH.md for the
source-verified-vs-live-smoke-tested distinction behind that choice. This choice held up well:
`workflowScript` is now the *only* way to batch several children in one call, since `tasks[]`
and `runs.all` are no longer alternatives but the sole surface, so ad-hoc multi-call (repeated
single-child `subagent({ agent, task })` calls in one turn) remains the simpler, still-valid
path deep-review always used. The
findings store's sole-writer invariant (reviewers/fixers return text, never write the store
themselves) holds under Pi because a child's `outputMode` defaults to `"inline"` at the pinned
version, confirmed in source (`src/shared/settings.ts`: `task.outputMode ?? config.outputMode ??
"inline"`). Note the added `config.outputMode` term: a project or user `subagents` config could
set a global `outputMode: "file-only"` default, which would override this default for every
child; this repo's `pi/settings.json` sets no such config, so the invariant holds as installed.
