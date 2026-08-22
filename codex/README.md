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

Your personal coding conventions live in **`ai-agents/AGENTS.md`**, not here. Both tools
read the same content:

- Claude Code: `~/.claude/CLAUDE.md` imports it via `@../ai-agents/AGENTS.md`.
- Codex: it is installed to `~/.codex/AGENTS.md`, which Codex reads for every project.

So `setup.ps1 -Module codex` copies `ai-agents/AGENTS.md` → `~/.codex/AGENTS.md`. Edit the
conventions in `ai-agents/AGENTS.md` only; re-run the installer to push the copy.

## Files

| File / Directory | Installed to | Notes |
|---|---|---|
| `config.toml` | `~/.codex/config.toml` | Model + standalone permissions; also registers the `bicep` MCP server (`[mcp_servers.bicep]` — scope and rationale in the file's comments) |
| `../ai-agents/AGENTS.md` (shared) | `~/.codex/AGENTS.md` | Personal conventions (sourced from the ai-agents module) |
| `../ai-agents/AGENTS.d/` (shared) | `~/.codex/AGENTS.d/` | Progressive-disclosure satellite files `AGENTS.md` links out to on demand (sourced from the ai-agents module) |
| `block-dangerous-git.sh` | `~/.codex/block-dangerous-git.sh` | `PreToolUse` hook that denies dangerous git commands — see "Git guardrails" below. Installed by `setup.ps1 -Module codex` only; `setup.sh` does not copy this file yet |
| `hooks.json` | merged into `~/.codex/hooks.json` | Tracked `hooks.PreToolUse` + `hooks.SessionStart` fragment; the installer merges both event keys, preserving any pre-existing foreign entry or hook in either (e.g. herdr's own `SessionStart` entry). Merged by `setup.ps1 -Module codex` only; `setup.sh` does not merge it yet |
| `ai-agents/skills/<name>/` (portable) | `~/.codex/skills/<name>/` | Portable global skills |
| `codex/skills/<name>/` | `~/.codex/skills/<name>/` | Codex-native skills (win on name collision) |
| `templates/work-AGENTS.md` | — (manual copy) | Drop into an Azure work repo root as `AGENTS.md` |

`config.toml` and the shared `AGENTS.md` are **copied** on both platforms (like the claude
module), so the live `~/.codex` copies can drift — re-run the installer (`setup.ps1 -Module
codex` or `./setup.sh -m codex`) to push repo → live.

## Git guardrails

`setup.ps1 -Module codex` installs a `PreToolUse` hook (matcher `Bash`) that blocks the same
destructive git commands the Claude Code `git-guardrails-claude-code` skill blocks: `git push`
(all variants), `git reset --hard`, `git clean -f`/`-fd`, `git branch -D`, and
`git checkout .` / `git restore .`. The matching logic is ported close to verbatim from
`claude/skills/git-guardrails-claude-code/scripts/block-dangerous-git.sh` — see
`codex/block-dangerous-git.sh`'s own comments for the one deliberate deviation (the
`python3`/`python` command-extraction tier now checks the pipeline actually succeeds, not just
that an executable exists on PATH — a bare `command -v python3` check is also true for
Windows's WindowsApps "app execution alias" stub, which exists on PATH but fails when run,
which would otherwise leave every command silently unmatched and disable the guardrail).

Blocked via the standard Codex hook contract: exit 2 with a reason on stderr. Registered
user-scope (`~/.codex/hooks.json`), matching this repo's own Claude Code guardrail scope
choice (`~/.claude/settings.json`). Because `~/.codex/hooks.json` may already carry herdr's own
`SessionStart` entry, the installer merges `hooks.PreToolUse` and `hooks.SessionStart` rather
than overwriting the file — `PreToolUse` filters out a whole foreign entry if any hook inside it
matches the guardrail, while `SessionStart` filters at the individual-hook level so a foreign
hook sharing an entry with a stale project-brain hook is kept — see `Install-Codex` in
`setup.ps1`.

Today this hook is installed only by `setup.ps1 -Module codex`; `setup.sh` does not yet copy
`block-dangerous-git.sh` or merge `hooks.json`, so it is not present on a Linux/WSL install.
The tracked `codex/hooks.json` fragment's hook command is `bash ~/.codex/block-dangerous-git.sh`,
which would be correct as-is on Linux once installed there. Codex CLI executes command hooks with no shell field, so on
Windows a bare `bash` resolves through normal PATH search — on a machine with WSL installed
(the common case), that hits `C:\Windows\System32\bash.exe`, the WSL launcher, where the
guardrail script does not exist, silently disabling the hook. On Windows the installer instead
rewrites the merged entry's command to a resolved absolute Git-for-Windows `bash.exe` and the
absolute installed script path (`Resolve-CodexGuardrailBash` in `setup.ps1`); if no real
Git-for-Windows bash can be found, it warns and skips the merge entirely rather than writing a
broken entry.

**Hook trust gate**: per the official hooks docs (`developers.openai.com/codex/hooks`), a
non-managed command hook needs to be reviewed and trusted before Codex will run it — use the
in-session `/hooks` command to inspect and trust a newly registered or changed hook (trust is
keyed to the hook definition's hash, so an edit requires re-trusting). On a fresh machine,
expect Codex to prompt for this the first time a `Bash` tool call reaches the guardrail after
`setup.ps1 -Module codex` has run. `--dangerously-bypass-hook-trust` skips the trust check for
one invocation — intended for automation that already vets its hook sources outside Codex, not
for routine interactive use.

## Project-brain SessionStart hook

`setup.ps1 -Module codex` registers a `SessionStart` hook that reuses the same
`ai-agents/skills/project-brain/scripts/session-start.ps1` resolver Claude Code's own
`SessionStart` hook runs (see `claude/settings.json`), projected to
`~/.codex/skills/project-brain/scripts/session-start.ps1` like any other portable skill. On
session init/resume/clear, it reads the hook's stdin `cwd`, resolves it to an active initiative
(in-repo `.claude/brain/core.md` first, else `~/.claude/project-brain/brains.json` +
registry.json), and injects that initiative's `core.md` + `STATUS.md` via
`hookSpecificOutput.additionalContext`. It fails safe — any error or no match exits 0 with no
output, never blocking a session.

Because command hooks run with no shell field (same reasoning as the git-guardrail bash
rewrite above), the tracked `~/...` placeholder in `codex/hooks.json` is rewritten to the
resolved absolute installed script path at merge time.

Check `core.md` + `STATUS.md` size for a given initiative against the roughly 2,500-token
`additionalContext` budget the Codex hook-output docs note — this repo does not solve
token-budgeting for oversized initiatives; keep those files lean. Measured against this
repo's own dotfiles brain (`E:\Personal Projects\brain\initiatives\dotfiles\`), the combined
`core.md` + `STATUS.md` payload is ~55.6K characters (~13.9K tokens at a 4-chars/token
estimate) — well over budget; expect Codex to truncate or drop the excess for initiatives
this large.

**Cosmetic caveat**: due to an upstream bug (`openai/codex#16933`), injected
`additionalContext` currently renders visibly in the Codex transcript instead of staying
hidden. For project-brain context that visibility is arguably a feature, not a problem — no
workaround is applied here.

## Platform support

Linux/WSL parity is provided by `setup.sh -m codex`: it installs the Codex CLI via OpenAI's
native installer, copies `config.toml` + `AGENTS.md` into `~/.codex/`, projects skills into
`~/.codex/skills/`, and registers the MCP reviewer. It does not yet install the git guardrail
hook or the project-brain `SessionStart` hook (both need the `hooks.json` merge covered above);
that merge is currently `setup.ps1 -Module codex`-only. One caveat: the `bicep` MCP server in `config.toml` needs `dnx`
from a .NET 10 SDK, which neither installer provisions on Linux — without it the server fails
at session start and Codex degrades to a session without Bicep tools (the entry is not
`required`, so startup itself is unaffected).

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
