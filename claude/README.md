# claude

Config for [Claude Code](https://claude.ai/code).

## Files

| File / Directory | Installed to | Notes |
|---|---|---|
| `settings.json` | `~/.claude/settings.json` | Model, theme, effort level, statusline |
| `statusline-command.sh` | `~/.claude/statusline-command.sh` | Token usage statusline script |
| `skills/<name>/` | `~/.claude/skills/<name>/` | Global custom skills (junctions/symlinks) |

## Settings

| Setting | Value | Notes |
|---|---|---|
| `model` | `sonnet` | Default model |
| `effortLevel` | `medium` | Default thinking effort |
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
