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
| `Microsoft.PowerShell_profile.JYJP-PC.ps1` | Home machine profile |
| `Microsoft.PowerShell_profile.WORK-PC.ps1` | Work machine profile |
| `Profile/Set-Prompt.ps1` | Prompt definition (git + Azure context) |

The installer generates a stub at `~/Documents/PowerShell/Microsoft.PowerShell_profile.ps1`
that dot-sources the machine-specific file — changes to the repo are live immediately.

## Profile architecture

The profile is structured in three phases to keep startup fast:

**Phase 1 — blocking (runs before first prompt):**
Single `PSModulePath` scan into `$global:ProfileModules` cache, PSReadLine
with `PredictionSource History`, all key bindings, prompt definition.

**Phase 2 — deferred (fires on first idle):**
PSFzf, WinGet CommandNotFound, Chocolatey, zoxide, upgrade to
`PredictionSource HistoryAndPlugin`. Guarded by `$global:ProfileDeferredDone`
so it runs exactly once per session.

**Phase 3 — async (background runspace):**
Azure context refresh on a 60-second timer, driven from `Set-Prompt.ps1`.

## Key bindings

| Chord | Action |
|---|---|
| `Ctrl+r` | Reverse history search |
| `Ctrl+t` | FZF file picker |
| `Ctrl+f` / `ForwardChar` | Forward char (also FZF provider chord) |
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

## Per-machine convention

Machine-specific files use `.<HOSTNAME>` before the extension. To add a new
machine, create `Microsoft.PowerShell_profile.<HOSTNAME>.ps1` and re-run the
installer.

## Install

```sh
./setup.ps1 -Module powershell
```

Stubs the profile into PS7, PS5, and VSCode locations. Junctions
`~/Documents/PowerShell/Profile` → `powershell/Profile/`.
