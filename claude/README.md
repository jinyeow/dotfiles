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
| `settings.json` | `~/.claude/settings.json` | Theme, effort level, editor mode, hooks, statusline (no `model` pin — chosen per session) |
| `CLAUDE.md` | `~/.claude/CLAUDE.md` | Claude-specific instructions; imports `AGENTS.md` via `@AGENTS.md` |
| `AGENTS.md` | `~/.claude/AGENTS.md` | Shared coding conventions (single source). The `codex` module installs the same file to `~/.codex/AGENTS.md` so Claude Code and Codex CLI agree. See `../codex/README.md`. |
| `statusline-command.sh` | `~/.claude/statusline-command.sh` | Token usage statusline script |
| `skills/<name>/` | `~/.claude/skills/<name>/` | Global custom skills |

**Install method.** `settings.json`, `CLAUDE.md`, `AGENTS.md`, and
`statusline-command.sh` are **symlinked** into `~/.claude`, and each skill directory is
**junctioned** (Windows) / symlinked (Linux). Windows file symlinks require **Developer
Mode** (Settings → For developers) — junctions don't need it but can't link files. Because
the live files are links to the repo, edits flow both ways and there is **no drift**: Claude
Code writing `settings.json`, or `/memory` appending to `CLAUDE.md`, updates the repo file
directly. Just `git diff` / commit when you want to capture the changes. (This replaces the
old copy-based install + planned live→repo sync.)

## Settings

| Setting | Value | Notes |
|---|---|---|
| `effortLevel` | `high` | Default thinking effort |
| `theme` | `dark-ansi` | Palette-based dark theme — readable under Zellij on Windows Terminal, where `auto` + truecolor diff backgrounds collapse into the pane (see `docs/zellij-windows-terminal-colors.md`) |
| `editorMode` | `vim` | Vim keybindings in the prompt input |
| `agentPushNotifEnabled` | `true` | Mobile push notifications (cloud/background agents — not local CLI) |
| `preferredNotifChannel` | `terminal_bell` | Built-in bell on the **needs-input** notification → marks the Zellij tab |
| `hooks` | Stop, Notification | Local completion alert — see Notifications |
| `statusLine` | command | Runs `statusline-command.sh` |

## Notifications

Alerts when Claude finishes (`Stop`) or is waiting on you (`Notification`), tuned for
the `Claude → Zellij → Windows Terminal` stack:

- **Audible beep** is the most reliable signal. Both hooks run `pwsh -NoProfile -Command
  "[console]::beep()"`, which goes through the system speaker and bypasses Zellij and
  Windows Terminal — so it reaches you even when WT is unfocused or minimized, provided audio
  is on (a muted/absent audio endpoint silences it).
- **Zellij tab mark** is the in-multiplexer indicator. A terminal bell (`BEL`) emitted
  inside a pane is **caught by Zellij** (it flags the tab) and is **not** forwarded out to
  Windows Terminal — so WT's own bell/taskbar-flash style never fires from inside Zellij.
  The tab mark is reliable on **needs-input** (Claude emits the `BEL` itself via
  `preferredNotifChannel: terminal_bell`) and best-effort on **done** (the `Stop` hook
  writes `[char]7`; whether a hook subprocess's `BEL` reaches the pane is not guaranteed).

PowerShell-native by design (this is a pwsh machine) — no `bash`/`printf '\a'`/`/dev/tty`.
For a visual toast on completion, replace the `Stop` hook's beep with
`New-BurntToastNotification -Text 'Claude Code','Done'` (needs `Install-Module BurntToast`);
the `Notification` hook still beeps unless you swap it too.

## Statusline

`statusline-command.sh` reads the JSON context piped by Claude Code and outputs
a statusline of the form
`Opus | 12.4k / 1M tokens (1%) | rate 70% (resets 2h14m) | ±main ↑2 *3 ?1 | PR#1234 ✓`.
Requires `jq` and `git`.

The percentage is computed from `used / context_window_size` — the denominator
comes straight from the JSON's `context_window.context_window_size` (200000, or
1000000 for extended-context models). The JSON's own `used_percentage` is
**not** used: it reflects Claude Code's internal compaction threshold rather than
the model's actual context limit.

The git segment (from `.workspace.current_dir`) mirrors the PowerShell prompt's
colors: `±branch` red when dirty / yellow when clean (`wt:` prefix in a worktree),
`↑N` ahead (green) / `↓N` behind (red) / `↕` diverged, and per-category file
counts `+N` staged (green), `*N` modified (yellow), `?N` untracked (magenta),
`!N` conflicts (red). Each count is omitted when zero; the whole segment is
absent outside a git repo.

The rate segment shows only when the 5-hour window is ≥50% consumed
(`rate_limits.five_hour`); when shown, it appends a countdown to the window reset
(`resets 2h14m`, or `resets 14m` under an hour) derived from `resets_at`. The
7-day window is not shown.

The PR segment appears only while an open PR exists for the branch (`.pr`):
`PR#N` plus a review-state glyph — `✓` approved (green), `✗` changes_requested
(red), `⋯` pending (yellow), `(draft)` for drafts (plain). Rendered as plain
colored text, not an OSC8 hyperlink, because the Zellij + Windows Terminal stack
mishandles escape sequences (see `docs/zellij-windows-terminal-colors.md`).

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

`_shared/` is **not a skill** — it holds resources shared by multiple skills (e.g.
`review-rubric.md`, the merged AGENTS.md + thermo-nuclear review rubric used by both
`codex-review` and `review-fix-loop`). It has no `SKILL.md`, so the harness ignores it as a
skill; it is still junctioned so skills can reference it via `../_shared/<file>`.

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
