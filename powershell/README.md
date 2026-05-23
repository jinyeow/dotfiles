# powershell

PowerShell 7 profile and prompt for Windows (and Linux where applicable).

## Prerequisites

| Tool | Purpose | Install |
|---|---|---|
| PowerShell 7+ | Shell | `winget install Microsoft.PowerShell` |
| [PSReadLine](https://github.com/PowerShell/PSReadLine) 2.2+ | Line editing | ships with pwsh 7; update via `Install-Module PSReadLine` |
| [PSFzf](https://github.com/kelleyma49/PSFzf) | Fzf integration | `Install-Module PSFzf` |
| [fzf](https://github.com/junegunn/fzf) | Fuzzy finder | `winget install junegunn.fzf` |
| [zoxide](https://github.com/ajeetdsouza/zoxide) | Smart `cd` | `winget install ajeetdsouza.zoxide` |
| [Az.Tools.Predictor](https://github.com/Azure/azure-powershell) | Azure command prediction | `Install-Module Az.Tools.Predictor` |
| [WinGet.CommandNotFound](https://github.com/microsoft/winget-command-not-found) | Package suggestions | installed via Microsoft Store |

## Files

| File | Notes |
|---|---|
| `Microsoft.PowerShell_profile.ps1` | Shared profile — used on all machines |
| `Profile/Set-Prompt.ps1` | Prompt definition (git + Azure context) |

The installer generates a stub at `~/Documents/PowerShell/Microsoft.PowerShell_profile.ps1`
that dot-sources the repo file — changes are live immediately without re-running setup.

## Profile architecture

The profile is structured in three phases to keep startup fast:

**Phase 1 — blocking (runs before first prompt):**
Single `PSModulePath` scan into `$global:ProfileModules` cache, PSReadLine
with `PredictionSource History`, all key bindings, prompt definition.
Sets `RIPGREP_CONFIG_PATH` and `FZF_DEFAULT_OPTS_FILE` pointing at repo files
(no copy needed). Reads `AppsUseLightTheme` from the registry once into
`$_isDark`, then sets `FZF_DEFAULT_OPTS` and `LG_CONFIG_FILE` (lazygit base +
theme) to catppuccin mocha or latte — mirrors nvim's theme detection.

**Phase 2 — deferred (fires on first idle):**
PSFzf, WinGet CommandNotFound, Chocolatey, zoxide, upgrade to
`PredictionSource HistoryAndPlugin`. Guarded by `$global:ProfileDeferredDone`
so it runs exactly once per session.

**Phase 3 — async (background runspace):**
Azure context refresh on a 60-second timer, driven from `Set-Prompt.ps1`.

## Key bindings

| Chord | Action |
|---|---|
| `Ctrl+r` | Reverse history search (fzf) |
| `Ctrl+t` | FZF file picker |
| `Alt+f` | FZF ripgrep search |
| `Alt+b` | FZF git branch switcher |
| `Alt+g` | FZF git worktree switcher |
| `Ctrl+f` | Forward char |
| `Ctrl+b` | Backward char |
| `Ctrl+p` / `Ctrl+n` | Previous / next history |
| `Ctrl+a` / `Ctrl+e` | Beginning / end of line |
| `Ctrl+w` | Delete word backward |
| `Ctrl+u` | Delete line backward |
| `Ctrl+Space` / `Shift+Tab` | Menu complete |
| `Ctrl+[` (Oem4) | Vi command mode |

## Prompt (`Set-Prompt.ps1`)

- Git branch and status — synchronous, 3 git processes per prompt
- Azure subscription context — async via background runspace, refreshed every 60s
- Last command exit status (colour coded) and execution time
- Truncated path for long directories
- Windows Terminal OSC 9;9 CWD tracking

## Per-machine differences

There is a single shared profile — no per-machine variants. Machine-specific
behaviour (work git identity, Azure subscription) is handled at other layers:
- Git identity via `[includeIf]` in `git/gitconfig`
- Az context loaded async in `Profile/Set-Prompt.ps1`

## Install

```sh
./setup.ps1 -Module powershell
```

Stubs the profile into PS7, PS5, and VSCode locations. Junctions
`~/Documents/PowerShell/Profile` → `powershell/Profile/`.
