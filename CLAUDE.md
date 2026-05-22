# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Repository scope

Personal dotfiles spanning Windows (PowerShell 7) and Linux/WSL (bash, Neovim, tmux, i3/bspwm). Active development is on the **Windows side**: the PowerShell profile under `powershell/`, the prompt in `powershell/Profile/Set-Prompt.ps1`, the Neovim Lua config under `nvim/`, and the git config under `git/`. Configs are organized into per-tool directories: `git/`, `nvim/`, `vim/`, `bash/`, `powershell/`, `tig/`, `tmux/`, `fzf/`, `curl/`. The Linux setup (`bootstrap.sh`, `Makefile`, `pwsh_profile.ps1`, the Arch package lists in the `install:` target, `config/bspwm`, `config/sxhkd`, etc.) is a legacy snapshot — touch only when explicitly asked.

`pwsh_profile.ps1` at the repo root is the **old** profile and is superseded by `powershell/Microsoft.PowerShell_profile.*.ps1`. Edit the per-machine file under `powershell/`, not the root one.

## Per-machine convention

Machine-specific variants use the suffix `.<HOSTNAME>` before the extension and live alongside the base file:
- `powershell/Microsoft.PowerShell_profile.JYJP-PC.ps1` (home)
- `powershell/Microsoft.PowerShell_profile.WORK-PC.ps1` (work)
- `nvim/` — no per-machine variant yet; use `.<HOSTNAME>` suffix on `init.lua` when needed
- `git/templates/hooks/prepare-commit-msg` (bash, JIRA-style `PROJ-123`) vs `prepare-commit-msg.WORK-PC` vs `prepare-commit-msg.ado.ps1` (Azure DevOps `#1234`)

Git identity is handled per-repo via `[includeIf]` rather than per-machine file variants — see the Git configuration section.

## Installation entry points

| Script | Target | Notes |
|---|---|---|
| `setup.ps1` | Windows | Module-based installer. `-Module git,neovim,vim,powershell,tig,fzf,curl` or `-Module all`. Supports `-DryRun`. |
| `setup.sh` | Linux / WSL | Module-based installer. `-m git,neovim,vim,powershell,bash,tig,tmux,fzf,curl` or `-m all`. Supports `--dry-run`. |
| `install.ps1` | Windows (legacy) | Old PS profile hardlinker — superseded by `setup.ps1 -Module powershell`. |
| `install.sh` | VSCode devcontainers (legacy) | Minimal `cp` installer — superseded by `setup.sh`. |
| `dotfiles-setup.sh` | Linux (legacy) | Module symlinker — superseded by `setup.sh`. |
| `bootstrap.sh`, `Makefile` | Arch Linux (legacy) | Heavy package install + symlinks; do not run on Windows. |

## PowerShell profile architecture

`Microsoft.PowerShell_profile.JYJP-PC.ps1` is structured as **three phases** to keep startup fast:

1. **Phase 1 (blocking, must stay cheap)**: module-availability cache (single `PSModulePath` scan into `$global:ProfileModules`), PSReadLine with `PredictionSource History` only, keybindings, dot-source `Profile/Set-Prompt.ps1`, az CLI argument completer, aliases.
2. **Phase 2 (deferred via `PowerShell.OnIdle`)**: `Initialize-DeferredProfile` loads PSFzf, WinGet CommandNotFound, Chocolatey, zoxide, and upgrades PSReadLine to `HistoryAndPlugin`. Guarded by `$global:ProfileDeferredDone` because `OnIdle` fires ~2×/sec.
3. **Phase 3 (async runspace)**: Az context refresh, driven from `Set-Prompt.ps1`.

When adding to the profile, classify by cost first — anything that loads .NET assemblies or scans the filesystem belongs in Phase 2, not Phase 1. Use the `$global:ProfileModules` cache rather than calling `Get-Module -ListAvailable` again.

## Prompt architecture (`Set-Prompt.ps1`)

- **Git is synchronous** — uses 3 git processes per prompt (`rev-parse` combined, `rev-list`, `status --porcelain`). The combined `rev-parse --abbrev-ref HEAD --git-dir --git-common-dir` doubles as the "are we in a repo" gate and detects worktrees (when git-dir ≠ git-common-dir).
- **Az context is async** via a long-lived background runspace, refreshed every 60s by a `System.Timers.Timer`. The timer's `Elapsed` handler runs in a separate runspace and cannot see main-session functions, so it bridges back via `New-Event 'Profile.AzRefreshRequested'` → `Register-EngineEvent` (which *does* run in the main session and can call `Start-AzContextRefresh`). Don't try to call session functions directly from `Register-ObjectEvent -Action`.
- **Idempotency**: every event registration unregisters prior subscribers first so `. $PROFILE` reloads don't stack handlers. `Get-EventSubscriber -SourceIdentifier` does **not** support wildcards — filter with `Where-Object`. `-SupportEvent` subscribers are hidden and require `-Force` to find.
- **`$?` / `$LASTEXITCODE` must be captured on the first two lines of `prompt`** before any other command runs, and `$LASTEXITCODE` is restored at the end so git calls inside the prompt don't leak a non-zero exit to the user's next command.
- Constants (ANSI escapes, admin check, length limits) are computed once into `$global:PromptConst`; the prompt body uses a `StringBuilder`.
- Emits Windows Terminal OSC 9;9 for CWD tracking when on a filesystem provider.

## Git configuration

Files live under `git/`: `gitconfig` (base), `gitconfig-work` (work overrides), `gitignore`, `gitmessage`, `templates/hooks/`.

- `core.hooksPath = ~/.git_templates/hooks` — global hook directory, so `prepare-commit-msg` runs on every repo. Branches like `feature/PROJ-123-foo` get `[PROJ-123]-` prepended to commit messages; the skip list (`master`, `develop`, `staging`, deploy/*) is in the hook.
- `init.templatedir = ~/.git_templates` — new repos inherit the hooks too.
- `init.defaultBranch = main`, `pull.ff = only`, `push.autoSetupRemote = true`, `rebase.autoStash = true`, `rebase.updateRefs = true` (stacked branches), `rerere.enabled = true`.
- Pager and diff filter are **delta** (`core.pager = delta`, `interactive.diffFilter = delta --color-only`).
- `url."git@github.com:".insteadOf` rewrites both `https://github.com/` and the `gh:` shorthand to SSH.
- **Identity**: base `gitconfig` sets personal `[user]` (`justin@puah.dev`). Work identity is applied per-repo via `[includeIf "hasconfig:remote.*.url:*hollard*"]` which includes `gitconfig-work` (sets `justin.puah@hollard.com.au` + `diff.tool = delta`). Requires Git 2.36+. For local-only work repos without a remote, run `git config user.email justin.puah@hollard.com.au` manually.
- **Installer**: `setup.ps1/setup.sh -Module git` installs `~/.gitconfig` and `~/.gitconfig-work` as git `[include]` stubs pointing to the repo files (cross-volume safe, always live), then junctions `~/.git_templates` → `git/templates/`.

## Conventions

- **EditorConfig**: 2-space default, LF, UTF-8, trim trailing whitespace, final newline. Overrides: 4-space for `*.sh`/`*.bash*`, `git*`/`.git*`, and `*.ps1`/`*.psd1`/`*.psm1`.
- **Commit style**: imperative, sometimes `feat:` / `fix:` prefixed (`feat: Refactor Set-Prompt.ps1 for async Azure and Git support`). Stay consistent with the surrounding files' recent history.
- **PowerShell**: target pwsh 7 (`#Requires -Version 7`), Vi edit mode, custom Vi cursor handler (`OnViModeChange` toggles `` `e[1 q `` ↔ `` `e[5 q ``), `Ctrl+Oem4` (left bracket) for `ViCommandMode` — see [PSReadLine #906](https://github.com/PowerShell/PSReadLine/issues/906#issuecomment-916847040).

## Neovim (`nvim/`)

Modular Lua config targeting Neovim 0.11+. Uses Neovim's built-in package system (`pack/*/start/`) with a lightweight auto-install wrapper — no external plugin manager. LSP is configured via the native `vim.lsp.config` / `vim.lsp.enable` API (not the lspconfig Lua framework).

Load order: `performance` → `user` → `plugins` → `options` → `keymaps` → `autocmds` → `treesitter` → `lsp` → `gitsigns` → `ui`

The `vim/` directory (Vimscript setup) is the older Vim config — kept as the Linux fallback, not the active Neovim config. `vim/vimrc` is the vimrc; Vim finds it automatically at `~/.vim/vimrc` (Linux) or `~/vimfiles/vimrc` (Windows).

### Key decisions (do not reverse without asking)

- **Plugin manager**: built-in `pack/*/start/` only. Plugins cloned via `git clone --depth=1` on first launch by `ensure_plugin()` in `plugins.lua`.
- **LSP API**: `vim.lsp.config` / `vim.lsp.enable` only. Do not use `require('lspconfig').xxx.setup{}`.
- **`_G.user_config`**: defined in `user.lua`, read by `lsp.lua` and `ui.lua`. Controls `profile` (`full`/`minimal`), LSP tool paths, and sunrise/sunset fallback hours for theme detection.
- **Profile system**: `NVIM_PROFILE=minimal` disables all plugins and uses a built-in colorscheme. Each module guards itself with an early return so the env var is the only thing to set.
- **Theme detection**: `ui.lua` queries OS dark/light mode (Windows registry → macOS `defaults` → GNOME `gsettings` → KDE `kreadconfig5`), falls back to `sunrise_hour`/`sunset_hour` from `user.lua`.
- **`vim.loader.enable()`**: must remain the first line of `performance.lua`.
- **Bicep filetype**: no built-in Neovim support — autocmd in `lsp.lua` registers `filetype = bicep` for `*.bicep`, only when `bicep_lsp_path` is non-empty.
- **Azure Pipelines filetype**: `autocmds.lua` sets `filetype = azure-pipelines` for `*.azure-pipelines.yml/yaml` so `azure_pipelines_ls` attaches exclusively and `yamlls` does not compete.
- **No per-machine variants yet**: single `init.lua` only — no `init.WORK-PC.lua`. Apply the `.<HOSTNAME>` suffix convention when machine-specific behaviour is needed.

### Install

Installed via `setup.ps1` (Windows) or `setup.sh` (Linux) at the repo root — see the Installation entry points section. The per-tool install scripts inside `nvim/` (`install.sh`, `install.ps1`, `install.py`) are an older standalone installer kept for backward compatibility.
