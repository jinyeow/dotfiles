# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Repository scope

Personal dotfiles spanning Windows (PowerShell 7) and Linux/WSL (bash, Neovim, tmux, i3/bspwm). Active development is on the **Windows side**: the PowerShell profile under `Documents/PowerShell/`, the prompt in `Documents/PowerShell/Profile/Set-Prompt.ps1`, the Neovim Lua config under `config/nvim/`, and the `gitconfig` + `git_templates/hooks/`. The Linux setup (`bootstrap.sh`, `Makefile`, `vimrc`, `bash/`, `pwsh_profile.ps1`, the Arch package lists in the `install:` target, `config/bspwm`, `config/sxhkd`, etc.) is a legacy snapshot — touch only when explicitly asked.

`pwsh_profile.ps1` at the repo root is the **old** profile and is superseded by `Documents/PowerShell/Microsoft.PowerShell_profile.*.ps1`. Edit the per-machine file under `Documents/PowerShell/`, not the root one.

## Per-machine convention

Machine-specific variants use the suffix `.<HOSTNAME>` before the extension and live alongside the base file:
- `Documents/PowerShell/Microsoft.PowerShell_profile.JYJP-PC.ps1` (home)
- `Documents/PowerShell/Microsoft.PowerShell_profile.WORK-PC.ps1` (work)
- `gitconfig` vs `gitconfig.WORK-PC`
- `config/nvim/init.lua` vs `config/nvim/init.WORK-PC.lua`
- `git_templates/hooks/prepare-commit-msg` (bash, JIRA-style `PROJ-123`) vs `prepare-commit-msg.WORK-PC` vs `prepare-commit-msg.ado.ps1` (Azure DevOps `#1234`)

When changing behaviour shared across machines, update the base file *and* mirror the change into the `.WORK-PC` variant unless the difference is intentional.

## Installation entry points

| Script | Target | Notes |
|---|---|---|
| `install.ps1` | Windows | Hardlinks `Documents/PowerShell/Microsoft.PowerShell_profile.ps1` into the three PS profile locations (PS5, VSCode PS, PS7). Backs up existing as `*.bak`. |
| `install.sh` | VSCode devcontainers | Minimal `cp` of bashrc, gitconfig, nvim, tmux. Not a full install. |
| `dotfiles-setup.sh` | Linux | `-d <module>` symlinks one of bash/git/nvim/tmux/vim/zsh; `-d all` does the lot. `-f` adds `ln -f`. |
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

- `core.hooksPath = ~/.git_templates/hooks` — global hook directory, so `prepare-commit-msg` runs on every repo. Branches like `feature/PROJ-123-foo` get `[PROJ-123]-` prepended to commit messages; the skip list (`master`, `develop`, `staging`, deploy/*) is in the hook.
- `init.templatedir = ~/.git_templates` — new repos inherit the hooks too.
- `init.defaultBranch = main`, `pull.ff = only`, `push.autoSetupRemote = true`, `rebase.autoStash = true`, `rebase.updateRefs = true` (stacked branches), `rerere.enabled = true`.
- Pager and diff filter are **delta** (`core.pager = delta`, `interactive.diffFilter = delta --color-only`).
- `url."git@github.com:".insteadOf` rewrites both `https://github.com/` and the `gh:` shorthand to SSH.
- `[user]` is set in the base `gitconfig` (`Justin Puah <justin@puah.dev>`); the work variant lives in `gitconfig.WORK-PC`.

## Conventions

- **EditorConfig**: 2-space default, LF, UTF-8, trim trailing whitespace, final newline. Overrides: 4-space for `*.sh`/`*.bash*`, `git*`/`.git*`, and `*.ps1`/`*.psd1`/`*.psm1`.
- **Commit style**: imperative, sometimes `feat:` / `fix:` prefixed (`feat: Refactor Set-Prompt.ps1 for async Azure and Git support`). Stay consistent with the surrounding files' recent history.
- **PowerShell**: target pwsh 7 (`#Requires -Version 7`), Vi edit mode, custom Vi cursor handler (`OnViModeChange` toggles `` `e[1 q `` ↔ `` `e[5 q ``), `Ctrl+Oem4` (left bracket) for `ViCommandMode` — see [PSReadLine #906](https://github.com/PowerShell/PSReadLine/issues/906#issuecomment-916847040).

## Neovim (`config/nvim/`)

Lua-based, `lazy.nvim` for plugins, `<Space>` as leader. `init.lua` is the active config; `init.WORK-PC.lua` is the work variant. Helpers in `lua/core/functions.lua` and `lua/core/mappings.lua` are loaded first. The standalone `vimrc` at the repo root and the `vim/` directory are the older Vimscript setup — kept for the Linux legacy path, not the active config.

---
# Claude Code Context — Dotfiles (Neovim Rebuild)

This file gives Claude Code context on decisions made during the initial build of this dotfiles repo.
Append this to the existing `CLAUDE.md` in the repo root.

---

## Neovim — New Config (In Progress)

A new Neovim configuration is being built from scratch alongside the existing one at `config/nvim/`.
The new config lives at `nvim/` and is **not yet active**. The existing `config/nvim/` config
(lazy.nvim-based, documented in the section above) is still the live config and should not be
modified until explicitly asked.

### Why a new config

The new config was designed from first principles with the following goals:

- Use the **built-in package manager** instead of lazy.nvim — intentional preference for native tooling
- Use the **Neovim 0.11+ native LSP API** (`vim.lsp.config` / `vim.lsp.enable`) instead of the
  deprecated `require('lspconfig').xxx.setup{}` pattern
- Modular file structure (`lua/config/*.lua`) so each concern is isolated and easy to maintain
- Performance-first from the start (`vim.loader.enable()`, disabled unused providers, scoped plugin activation)
- Tailored language support for the active stack: Bicep, JSON, YAML, PowerShell, Azure DevOps pipelines

### Planned next step

Once the new config is stable, Claude Code will be asked to compare `config/nvim/` and `nvim/`,
identify anything worth carrying over (keymaps, options, plugin equivalents), and then remove the
old config. Do not do this automatically — wait to be asked.

### New config location

```
nvim/                        # new config source (not yet installed)
├── init.lua
└── lua/config/
    ├── performance.lua
    ├── user.lua
    ├── plugins.lua
    ├── options.lua
    ├── keymaps.lua
    ├── autocmds.lua
    ├── treesitter.lua
    ├── lsp.lua
    ├── gitsigns.lua
    └── ui.lua
```

Install scripts at the repo root copy `nvim/` to the OS config location:

| Script | Platform |
|---|---|
| `install.sh` | Linux (`~/.config/nvim`) |
| `install.ps1` | Windows (`%LOCALAPPDATA%\nvim`) |
| `install.py` | Cross-platform (Python 3.10+) |

The Python installer exposes `install(source_dir: Path | None)` so it can be called from a future
dotfiles orchestrator without shelling out.

### Key decisions made (do not reverse without asking)

**Plugin manager — built-in only**
Do not suggest lazy.nvim. The built-in package manager was chosen deliberately. Plugins are cloned
via `git clone --depth=1` into `stdpath('data')/site/pack/plugins/start/` on first launch.

**LSP API — `vim.lsp.config` / `vim.lsp.enable`**
Do not use `require('lspconfig').xxx.setup{}` — deprecated in Neovim 0.11+. nvim-lspconfig is
still included as a plugin for its server definitions, but the Lua framework is not used.

**`_G.user_config` global**
Defined in `user.lua`, read by `lsp.lua`. Holds paths to the Bicep Language Server `.dll` and the
PowerShell Editor Services bundle. Both LSPs are silently skipped if the path is empty string.
This avoids errors on machines where those tools are not installed.

**Bicep filetype detection**
Neovim has no built-in `.bicep` filetype support. An autocmd in `lsp.lua` sets
`filetype = 'bicep'` on `BufNewFile`/`BufRead` for `*.bicep`. Only registered when
`bicep_lsp_path` is non-empty.

**Azure Pipelines filetype detection**
`*.azure-pipelines.yml` and `*.azure-pipelines.yaml` are set to `filetype = azure-pipelines`
in `autocmds.lua` so `azure_pipelines_ls` attaches exclusively and `yamlls` does not compete.

**Python provider kept**
All other providers (`ruby`, `perl`, `node`) are disabled for startup performance.
`python3_provider` is retained (`nil`, not `0`) for future AI/ML plugin work.

**render-markdown.nvim scoped**
Scoped to `file_types = { 'markdown' }` and `render_modes = { 'n', 'v' }`. Does not activate
in insert mode — intentional for performance.

**`vim.loader.enable()` must remain first**
This is the first line of `performance.lua`, which is the first module loaded. Do not move it.

**Per-machine convention**
The existing dotfiles repo uses a `.<HOSTNAME>` suffix convention for machine-specific variants
(e.g. `init.WORK-PC.lua`). The new config does not yet have work/home variants — this will be
addressed when the old config is retired and combined.

### Plugins in the new config

| Plugin | Purpose |
|---|---|
| nvim-treesitter | Syntax highlighting and text objects |
| nvim-treesitter-textobjects | Function/class text objects |
| fzf + fzf.vim | Fuzzy finding |
| vim-fugitive | Git commands |
| vim-commentary | Commenting (`gcc`) |
| vim-repeat | Better `.` repeat |
| catppuccin | Colour scheme (mocha) |
| mini.surround | Surround text objects |
| nvim-lspconfig | LSP server definitions |
| schemastore.nvim | JSON/YAML schema catalogue |
| gitsigns.nvim | In-buffer git signs and hunk actions |
| render-markdown.nvim | In-buffer markdown rendering |

### LSP servers

| Server | Language | Notes |
|---|---|---|
| jsonls | JSON | schemastore schemas |
| yamlls | YAML | schemastore schemas |
| azure_pipelines_ls | Azure Pipelines YAML | |
| marksman | Markdown | |
| bicep | Bicep | requires `bicep_lsp_path` in user.lua |
| powershell_es | PowerShell | requires `pwsh_bundle_path` in user.lua |
