# codex

Config for [OpenAI Codex CLI](https://developers.openai.com/codex), wired up as a
read-only second-opinion reviewer for Claude Code.

## How it fits with Claude Code

Claude Code is the primary driver. Codex is registered as the `codex` MCP server so Claude
can ask it for a cross-model review on demand (see the `/codex-review` skill and the "Codex
second opinion" section in `claude/CLAUDE.md`). The integration is one-way: Claude → Codex.

Two permission postures, one config file:

| Path | Posture | Where set |
|---|---|---|
| **Reviewer** (Claude calls Codex) | read-only, non-interactive, medium effort | `-c` overrides on the MCP registration: `codex mcp-server -c sandbox_mode="read-only" -c approval_policy="never" -c model_reasoning_effort="medium"` |
| **Standalone** (you run `codex`) | workspace-write, asks first | `config.toml` (`approval_policy = "on-request"`, `sandbox_mode = "workspace-write"`) |

## Shared conventions (single source)

Your personal coding conventions live in **`claude/AGENTS.md`** (sibling to `CLAUDE.md`),
not here. Both tools read the same content:

- Claude Code: `~/.claude/CLAUDE.md` imports it via `@AGENTS.md`.
- Codex: it is installed to `~/.codex/AGENTS.md`, which Codex reads for every project.

So `setup.ps1 -Module codex` copies `claude/AGENTS.md` → `~/.codex/AGENTS.md`. Edit the
conventions in `claude/AGENTS.md` only; re-run the installer to push the copy.

## Files

| File / Directory | Installed to | Notes |
|---|---|---|
| `config.toml` | `~/.codex/config.toml` | Model + standalone permissions; also registers the `bicep` MCP server (`[mcp_servers.bicep]`, `Azure.Bicep.McpServer` via `dnx`) for diagnostics, formatting, decompile, resource-type schemas, and best-practices lookup — no symbol navigation |
| `claude/AGENTS.md` (shared) | `~/.codex/AGENTS.md` | Personal conventions (sourced from the claude module) |
| `claude/AGENTS.d/` (shared) | `~/.codex/AGENTS.d/` | Progressive-disclosure satellite files `AGENTS.md` links out to on demand (sourced from the claude module) |
| `ai-agents/skills/<name>/` (portable) | `~/.codex/skills/<name>/` | Portable global skills |
| `codex/skills/<name>/` | `~/.codex/skills/<name>/` | Codex-native skills (win on name collision) |
| `templates/work-AGENTS.md` | — (manual copy) | Drop into an Azure work repo root as `AGENTS.md` |

`config.toml` and the shared `AGENTS.md` are **copied** on both platforms (like the claude
module), so the live `~/.codex` copies can drift — re-run the installer (`setup.ps1 -Module
codex` or `./setup.sh -m codex`) to push repo → live.

## Platform support

Linux/WSL parity is provided by `setup.sh -m codex`: it installs the Codex CLI via OpenAI's
native installer, copies `config.toml` + `AGENTS.md` into `~/.codex/`, projects skills into
`~/.codex/skills/`, and registers the MCP reviewer — the same steps as `setup.ps1 -Module
codex` on Windows.

## Fail-closed install gating

If the native installer fails and `codex` is still not on PATH afterward, setup stops before
touching any Codex configuration or resources — no `config.toml`/`AGENTS.md` copy, no MCP
registration, no skill symlinks — and prints an actionable diagnostic (what failed, and the
manual install/re-run command). A successful install continues through configuration and
projection as normal. This mirrors the Claude CLI bootstrap gating (see `claude/README.md`).

## Manual login boundary

Setup never runs `codex login` — it only installs the CLI and projects configuration. Running
`codex login` (interactive ChatGPT-account OAuth) remains a manual, one-time step you run
yourself, on both platforms.

## Skills

Codex reads the same `SKILL.md` format Claude does (optionally with an `agents/openai.yaml`
per skill), so the installer projects skills into `~/.codex/skills/` from two sources:

1. **`ai-agents/skills/` (portable)** — every portable skill is runtime-neutral and is
   projected to Codex.
2. **`codex/skills/` (Codex-native)** — on a name collision the Codex-native skill wins;
   the shared one is filtered out up front (not overwritten, keeping the junctions idempotent).

Claude-native skills and Claude support content under `claude/skills/` are never projected to Codex.

The shared `council` skill, its four aliases, and the review→fix skills (`quick-review`,
`deep-review`, `review-fix-loop`, `fix-findings`) are available after setup. They are prompt
orchestration contracts, not installed custom agents: the host must use a Codex version
whose native delegation can isolate at least two workers, or report
`unsupported-capability`. Quick mode is the default; debate and external Codex are opt-in.
On a Codex host, `--codex` is rejected unless a separately configured adapter supplies a
genuinely independent provider/context. The review→fix skills' findings-store write path
on a Codex host is an open gap — a live probe on this machine could not get
`workspace-write` to engage — so the four stateful skills are not yet proven end-to-end
on Codex; see `ai-agents/skills/deep-review/DISPATCH.md` ("Sole-writer invariant under
Codex") for the recorded probe.

**Confirmed minimum version and invocation syntax** (smoke-tested 2026-08-12, closing the
open item previously here): `codex-cli 0.147.0` is confirmed working — `codex features
list` shows `multi_agent` as `stable`/enabled by default on this install. No earlier version
was tested, so 0.147.0 is the asserted floor, not a verified lower bound. Dispatch is the
native `multi_agent` tool surface (`spawn_agent`/`wait`/`send_message`), not a CLI flag or
subcommand; a real end-to-end run from a non-interactive session:

```
codex exec -s read-only -c approval_policy=never --json \
  "Spawn two parallel subagents: one reads correctness.py and reports one line on \
   correctness, one reads conventions.py and reports one line on naming conventions. \
   Wait for both, then summarize both findings in your final response, each line \
   prefixed with the filename."
```

The `--json` event stream showed both children resolve as `collab_tool_call` (`tool:
"wait"`) items, then a single primary-thread `agent_message` with both files' correct,
labelled summaries — no child output reached the transcript directly, confirming the
primary thread is the sole writer of its own final response. This smoke test spawned
anonymous generic subagents only, not the named `[agents.<name>]` roles below, so it
proves the `spawn_agent`/`wait` dispatch primitive, not per-role behavior.

Per-dimension custom agents (read-only reviewers, a workspace-write fixer) are declared
as `[agents.<name>]` tables in `config.toml`, resolved by name as `agent_type` — see
`ai-agents/skills/deep-review/DISPATCH.md` (Codex CLI section) for the full mapping.
Per-role `sandbox_mode`/`developer_instructions`/`mcp_servers` are unsupported at the
pinned codex-cli 0.147.0 (`description` is the only working per-role channel); real
enforcement is the orchestrating session's own top-level `sandbox_mode` — which may itself
be `workspace-write`, in which case nothing enforces a reviewer's read-only posture — see
DISPATCH.md for the schema evidence and the live test that confirmed table names
resolve as `agent_type`. Not exercised by this smoke test: the four skills' complete
pipelines end-to-end, named custom roles, or per-role sandbox enforcement — only the
underlying anonymous-subagent dispatch primitive.

Codex's own built-in skills live alongside at `~/.codex/skills/.system/` and are never
touched by this installer. Claude-specific frontmatter fields (e.g. `disable-model-invocation`)
are ignored by Codex — the per-skill equivalent is a sibling `agents/openai.yaml` with
`policy: { allow_implicit_invocation: false }` (see `refactor-agents-md` for an example).

"Agent" means two distinct things in Codex's vocabulary. Per-skill identity is an
`agents/openai.yaml` file nested inside a skill folder — no separate junction needed, the
skills junction covers it. Separately, `multi_agent` dispatch roles (the read-only
reviewers and workspace-write fixer used by the review skills above) are `[agents.<name>]`
tables in `config.toml`, resolved by `spawn_agent`'s `agent_type` — unlike Claude's agents,
these aren't files, they're config entries.

`codex/skills/` is empty for now — a skill there is only needed when the Codex flavour must
differ from the portable skill. Create `codex/skills/<name>/SKILL.md` and
re-run `setup.ps1 -Module codex`.

## Install

1. `setup.ps1 -Module codex` (Windows) or `./setup.sh -m codex` (Linux/WSL) — installs the
   Codex CLI (native installer), copies `config.toml` + `AGENTS.md` into `~/.codex/`, projects
   portable skills plus any `codex/skills/` variants into `~/.codex/skills/`, and registers
   the read-only MCP reviewer at user scope in Claude Code. MCP registration only happens when
   both the `claude` CLI is on PATH and `~/.claude/settings.json` already exists (i.e. the
   claude module has run first); otherwise it is skipped with no changes to `~/.claude.json`.
2. `codex login` — interactive ChatGPT-account OAuth (run this yourself; one-time).

`-Module ai-agents` (`-m ai-agents` on Linux) runs Claude, then Codex, then Pi in one
invocation — Claude first satisfies the MCP-registration gate above — but `codex` remains
independently invocable on its own.

Verify:

```powershell
codex --version
claude mcp list                 # codex should be listed
codex exec "reply with: ok"     # standalone smoke test (after login)
```

## Model

`gpt-5.5` (current Codex default). Newer models may require ChatGPT login rather than an
API key — `codex login` (no flags) uses your ChatGPT account, which is what we want.
