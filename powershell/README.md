# powershell

PowerShell 7 profile and prompt for Windows (and Linux where applicable).

## Prerequisites

| Tool | Purpose | Install |
|---|---|---|
| PowerShell 7+ | Shell | `winget install Microsoft.PowerShell` |
| [PSReadLine](https://github.com/PowerShell/PSReadLine) 2.2+ | Line editing | ships with pwsh 7; update via `Install-Module PSReadLine` |
| [PSFzf](https://github.com/kelleyma49/PSFzf) | Fzf integration | `Install-Module PSFzf` |
| [git-completion](https://github.com/kzrnm/git-completion-pwsh) | Git tab completion | `Install-Module git-completion` |
| [fzf](https://github.com/junegunn/fzf) | Fuzzy finder | `winget install junegunn.fzf` |
| [zoxide](https://github.com/ajeetdsouza/zoxide) | Smart `cd` | `winget install ajeetdsouza.zoxide` |
| [Az.Tools.Predictor](https://github.com/Azure/azure-powershell) | Azure command prediction | `Install-Module Az.Tools.Predictor` |
| [WinGet.CommandNotFound](https://github.com/microsoft/winget-command-not-found) | Package suggestions | installed via Microsoft Store |
| [jujutsu (jj)](https://github.com/jj-vcs/jj) | _Optional_ — jj VCS segment in the prompt | `winget install jj-vcs.jj` |

## Files

| File | Notes |
|---|---|
| `Microsoft.PowerShell_profile.ps1` | Shared profile — used on all machines |
| `Profile/Set-Prompt.ps1` | Prompt definition (jj/git + Azure context) |

The installer generates a stub at `~/Documents/PowerShell/Microsoft.PowerShell_profile.ps1`
that dot-sources the repo file — changes are live immediately without re-running setup.

## Scripts (`Scripts/`)

Standalone PowerShell tools (not loaded by the profile — run on demand). Each has
comment-based help; run `Get-Help .\Scripts\<Name>.ps1 -Full`.

| Script | Purpose |
|---|---|
| `Set-CodingFont.ps1` | Switch the coding font across **all** dotfiles targets at once — Windows Terminal (live + repo), VS Code (live + repo snapshot), and Vim guifont. `Set-CodingFont commit` |
| `Install-CodingFont.ps1` | Download + per-user install + session-activate Nerd Font (Mono) faces from the nerd-fonts release. `Install-CodingFont CommitMono` |
| `New-FontComparison.ps1` | Self-contained side-by-side HTML/PNG comparison of the candidate fonts with a PowerShell/C#/Bicep language switcher. `-Fonts` filters the set |
| `New-FontGlyphTest.ps1` | Glyph-separation torture test (rn/m, cl/d, vv/w, 1lI\|, 0O) across Commit/JetBrains/0xProto |
| `New-FontLigatureTest.ps1` | Ligatures-on vs -off comparison so you can see what each font actually fuses |

The `New-Font*` tools subset each font to the sample glyphs and embed them as base64 woff2,
so the output HTML renders the real fonts in any browser. They need Python with
`fonttools` + `brotli` (`pip install fonttools brotli`) for subsetting and Edge for the PNG.
Generated `.font-*.html`/`.png` land at the repo root and are git-ignored.

## Profile architecture

The profile is structured in three phases to keep startup fast:

**Phase 1 — blocking (runs before first prompt):**
Single `PSModulePath` scan into `$global:ProfileModules` cache, PSReadLine
with `PredictionSource History`, all key bindings, prompt definition.
Sets `RIPGREP_CONFIG_PATH` and `FZF_DEFAULT_OPTS_FILE` pointing at repo files
(no copy needed). Reads `AppsUseLightTheme` from the registry once into
`$_isDark`, then sets `FZF_DEFAULT_OPTS`, `LG_CONFIG_FILE` (lazygit base +
theme), and `EZA_CONFIG_DIR` (eza theme dir) to catppuccin mocha or latte —
mirrors nvim's theme detection.
Sets `_ZO_RESOLVE_SYMLINKS=1` so zoxide stores resolved paths; prevents
duplicate database entries when navigating through junctions.

**Phase 2a — first idle:**
PSFzf, zoxide, upgrade to `PredictionSource HistoryAndPlugin`, the fd-backed
`FZF_*_COMMAND` vars (kept separate from `ripgreprc` so pickers stay
`.gitignore`-clean while rg search stays exhaustive), the eza `ll`/`la`/`lt`
helpers, and the Azure context timer (`Initialize-AzTimer`, moved off the load
path). Guarded by
`$global:ProfileDeferredDone`. Interactive tools needed immediately.

**Phase 2b — next idle:**
az + zellij tab-completers, git-completion (+ `g` alias registration), WinGet
CommandNotFound. Guarded by `$global:ProfileDeferredSecondaryDone`. Split from 2a
so the first keypress isn't blocked by their import cost.

**Phase 3 — async (background runspace):**
Azure context refresh on a 60-second timer. The timer is created in Phase 2a
(`Initialize-AzTimer`); the refresh itself runs in a background runspace wired up
in `Set-Prompt.ps1`.

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

- jj (Jujutsu) change-id, closest bookmark, ahead count, and state — shown instead of git in jj repos (takes precedence in colocated repos; toggle `ShowJj`). Gate is a filesystem walk; up to 3 jj processes, all `--ignore-working-copy`. Renders `jj:<change-id> <bookmark> ↑<dist> *<files> ∅ ✎` (`∅` empty, `✎` no description, `!` conflict)
- Git branch and status — synchronous, 3 git processes per prompt (used when not in a jj repo)
- Azure subscription context — async via background runspace, refreshed every 60s
- Last command exit status (colour coded) and execution time
- Truncated path for long directories
- Windows Terminal OSC 9;9 CWD tracking; also syncs the Win32 process CWD so Zellij opens new panes in the current directory

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
