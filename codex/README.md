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
| `config.toml` | `~/.codex/config.toml` | Model + standalone permissions |
| `claude/AGENTS.md` (shared) | `~/.codex/AGENTS.md` | Personal conventions (sourced from the claude module) |
| `claude/skills/<name>/` (shared) | `~/.codex/skills/<name>/` | Global skills, minus a Claude-only denylist |
| `skills/<name>/` | `~/.codex/skills/<name>/` | Codex-native skills (win on name collision) |
| `templates/work-AGENTS.md` | — (manual copy) | Drop into an Azure work repo root as `AGENTS.md` |

`config.toml` and the shared `AGENTS.md` are **copied** on Windows (like the claude module),
so the live `~/.codex` copies can drift — re-run `setup.ps1 -Module codex` to push repo → live.

## Skills

Codex reads the same `SKILL.md` format Claude does (optionally with an `agents/openai.yaml`
per skill), so the installer junctions skills into `~/.codex/skills/` from two sources, in
order:

1. **`claude/skills/` (shared)** — every subdirectory, including the `_shared/` support dir
   (skills reference it via `../_shared`), **minus** a denylist of skills coupled to the
   Claude Code harness: `codex-review` (drives Codex *from* Claude — circular inside Codex),
   `handoff` (pairs with Claude's SessionStart inject hook), and `git-guardrails-claude-code`
   (installs Claude Code hooks). The denylist lives in `setup.ps1` (`$claudeOnlySkills`).
2. **`codex/skills/` (Codex-native)** — on a name collision the Codex-native skill wins;
   the shared one is filtered out up front (not overwritten, keeping the junctions idempotent).

Codex's own built-in skills live alongside at `~/.codex/skills/.system/` and are never
touched by this installer. Claude-specific frontmatter fields (e.g. `disable-model-invocation`)
are ignored by Codex.

Unlike Claude, Codex has no separate top-level "agents" concept — an "agent" is just an
`agents/openai.yaml` file nested inside a skill folder, so there's no separate agents
junction to wire up; the skills junction covers both.

`codex/skills/` is empty for now — a skill there is only needed when the Codex flavour must
differ from the shared `claude/skills/` one. Create `codex/skills/<name>/SKILL.md` and
re-run `setup.ps1 -Module codex`.

## Install

1. `setup.ps1 -Module codex` — installs the Codex CLI (native installer), copies
   `config.toml` + `AGENTS.md` into `~/.codex/`, junctions the shared `claude/skills/`
   (minus the denylist) plus any `codex/skills/` into `~/.codex/skills/`, and registers
   the read-only MCP reviewer at user scope in Claude Code.
2. `codex login` — interactive ChatGPT-account OAuth (run this yourself; one-time).

Verify:

```powershell
codex --version
claude mcp list                 # codex should be listed
codex exec "reply with: ok"     # standalone smoke test (after login)
```

## Model

`gpt-5.5` (current Codex default). Newer models may require ChatGPT login rather than an
API key — `codex login` (no flags) uses your ChatGPT account, which is what we want.
