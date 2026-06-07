# claude

Config for [Claude Code](https://claude.ai/code).

## Binary install method

Install the Claude Code CLI with the **native installer** (`irm
https://claude.ai/install.ps1 | iex` on Windows → `~\.local\bin\claude.exe`),
**not** via Volta/npm-global. A Volta-managed npm-global install conflicts with
Claude Code's own background auto-updater: both mutate the same install, leaving
the PATH shim out of sync with Volta's package dir and printing `'"...\bin\
claude.exe"' is not recognized as an internal or external command` mid-update
(the updater shells through Volta's `claude.cmd` while the 240 MB exe is being
swapped). The native install self-updates cleanly with no Volta in the loop.
Verify with `claude doctor` (install method = native) and `Get-Command claude`
(resolves to `~\.local\bin`, no Volta entries). This repo only tracks the
*config* under `~/.claude`, not the binary.

## Files

| File / Directory | Installed to | Notes |
|---|---|---|
| `settings.json` | `~/.claude/settings.json` | Model, theme, effort level, statusline |
| `CLAUDE.md` | `~/.claude/CLAUDE.md` | Claude-specific instructions; imports `AGENTS.md` via `@AGENTS.md` |
| `AGENTS.md` | `~/.claude/AGENTS.md` | Shared coding conventions (single source). The `codex` module installs the same file to `~/.codex/AGENTS.md` so Claude Code and Codex CLI agree. See `../codex/README.md`. |
| `statusline-command.sh` | `~/.claude/statusline-command.sh` | Token usage statusline script |
| `skills/<name>/` | `~/.claude/skills/<name>/` | Global custom skills |

**Install method differs by OS.** On **Windows**, `settings.json`, `CLAUDE.md`,
`AGENTS.md`, and `statusline-command.sh` are **copied** (a file symlink would need
Developer Mode/admin), and each skill directory is **junctioned**. On **Linux**, all
are **symlinked**. Consequence on Windows: because they are copies and Claude
Code writes to `settings.json` / `CLAUDE.md` itself, the live files can drift
from the repo — re-run `setup.ps1 -Module claude` to push repo → live, and copy
changes back by hand (or just edit the repo file) to go live → repo.

## Settings

| Setting | Value | Notes |
|---|---|---|
| `model` | `sonnet` | Default model |
| `effortLevel` | `high` | Default thinking effort |
| `theme` | `dark-ansi` | Palette-based dark theme — readable under Zellij on Windows Terminal, where `auto` + truecolor diff backgrounds collapse into the pane (see `docs/zellij-windows-terminal-colors.md`) |
| `editorMode` | `vim` | Vim keybindings in the prompt input |
| `agentPushNotifEnabled` | `true` | Mobile push notifications |
| `statusLine` | command | Runs `statusline-command.sh` |

## Statusline

`statusline-command.sh` reads the JSON context piped by Claude Code and outputs
a statusline of the form `Sonnet 4.6 | 12.4k / 1M tokens (1%)`. Requires `jq`.

The percentage is computed from `used / model_max` (not the JSON's
`used_percentage`, which reflects Claude Code's internal compaction threshold
rather than the model's actual context limit).

## Skills

`claude/skills/` holds global custom skills. Each subdirectory is a skill:

```
claude/skills/
  my-skill/
    SKILL.md    ← skill definition
```

The installer junctions (Windows) or symlinks (Linux) each skill directory into
`~/.claude/skills/`, making it available in every project. To add a skill,
create its subdirectory here and re-run `setup.ps1 -Module claude`.

Built-in Claude Code skills (`handoff`, `code-review`, etc.) are provided by
the harness and do not need to be installed.

## Install

```
.\setup.ps1 -Module claude   # Windows
./setup.sh -m claude         # Linux / WSL
```

**Not tracked** (excluded by design): `.credentials.json`, `history.jsonl`,
`mcp-needs-auth-cache.json`, `stats-cache.json`, per-project state under
`projects/`, and session data.
