# claude

Config for [Claude Code](https://claude.ai/code).

## Files

| File | Installed to | Notes |
|---|---|---|
| `settings.json` | `~/.claude/settings.json` | Model, theme, effort level, statusline |
| `statusline-command.sh` | `~/.claude/statusline-command.sh` | Token usage statusline script |

## Settings

| Setting | Value | Notes |
|---|---|---|
| `model` | `sonnet` | Default model |
| `effortLevel` | `medium` | Default thinking effort |
| `theme` | `auto` | Follows OS dark/light mode |
| `statusLine` | command | Runs `statusline-command.sh` |

## Statusline

`statusline-command.sh` reads the JSON context piped by Claude Code and outputs
token usage in the footer, e.g. `12.4k / 200k tokens (6%)`. Requires `jq`.

## Install

```
.\setup.ps1 -Module claude   # Windows
./setup.sh -m claude         # Linux / WSL
```

**Not tracked** (excluded by design): `.credentials.json`, `history.jsonl`,
`mcp-needs-auth-cache.json`, `stats-cache.json`, per-project state under
`projects/`, and session data.
