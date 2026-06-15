# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Repository scope

Personal dotfiles spanning Windows (PowerShell 7) and Linux/WSL (bash, Neovim, tmux, i3/bspwm). Active development is on the **Windows side**: the PowerShell profile under `powershell/`, the prompt in `powershell/Profile/Set-Prompt.ps1`, the Neovim Lua config under `nvim/`, the Zellij config under `zellij/`, the Yazi config under `yazi/`, and the git config under `git/`. Configs are organized into per-tool directories: `git/`, `nvim/`, `vim/`, `bash/`, `powershell/`, `tig/`, `tmux/`, `zellij/`, `yazi/`, `fzf/`, `curl/`, `claude/`, `codex/`, `windowsterminal/`. The Linux setup (`bootstrap.sh`, `Makefile`, `pwsh_profile.ps1`, the Arch package lists in the `install:` target, `config/bspwm`, `config/sxhkd`, etc.) is a legacy snapshot — touch only when explicitly asked.

`pwsh_profile.ps1` at the repo root is the **old** profile and is superseded by `powershell/Microsoft.PowerShell_profile.*.ps1`. Edit the per-machine file under `powershell/`, not the root one.

Note the two `CLAUDE.md` files: this root one is **project instructions for the dotfiles repo**; `claude/CLAUDE.md` is the **global user instructions** that `setup.ps1 -Module claude` installs to `~/.claude/CLAUDE.md`. They are unrelated — don't merge them. See `claude/README.md` for the Claude Code module (settings, statusline, skills); note its files are **copied** on Windows (so the live `~/.claude` copies can drift) and **symlinked** on Linux.

**Shared agent conventions live in `claude/AGENTS.md`** (single source). `claude/CLAUDE.md` imports it via `@AGENTS.md`, and the `codex` module installs the same file to `~/.codex/AGENTS.md`, so Claude Code and Codex CLI follow identical coding conventions. Edit conventions in `claude/AGENTS.md` only; keep `CLAUDE.md` to Claude-specific behaviour. See the Claude + Codex integration section below.

## Per-machine convention

Machine-specific variants use the suffix `.<HOSTNAME>` before the extension and live alongside the base file:
- `nvim/` — no per-machine variant yet; use `.<HOSTNAME>` suffix on `init.lua` when needed

The PowerShell profile (`powershell/Microsoft.PowerShell_profile.ps1`) is a single shared file — no per-machine variant. Git identity is handled per-repo via `[includeIf]` — see the Git configuration section.

## Installation entry points

| Script | Target | Notes |
|---|---|---|
| `setup.ps1` | Windows | Module-based installer. `-Module neovim,vim,powershell,git,bash,tig,tmux,zellij,yazi,curl,claude,codex,lazygit,windowsterminal,bat,vscode,winget` or `-Module all`. Supports `-DryRun`. |
| `setup.sh` | Linux / WSL | Module-based installer. `-m neovim,vim,powershell,git,bash,tig,tmux,zellij,curl,claude,lazygit,windowsterminal` or `-m all`. Supports `--dry-run`. (No `codex` module yet — Windows only.) |

## PowerShell profile architecture

`Microsoft.PowerShell_profile.ps1` is structured as **three phases** to keep startup fast:

1. **Phase 1 (blocking, must stay cheap)**: module-availability cache (single `PSModulePath` scan into `$global:ProfileModules`), PSReadLine with `PredictionSource History` only, keybindings, dot-source `Profile/Set-Prompt.ps1` (which defines but no longer *calls* `Initialize-AzTimer`), aliases, tool wrapper functions (`y` for yazi).
2. **Phase 2a (first idle)**: `Initialize-DeferredProfile` loads PSFzf and zoxide, upgrades PSReadLine to `HistoryAndPlugin`, sets the fd-backed `FZF_*_COMMAND` vars, defines the eza `ll`/`la`/`lt` helpers, and calls `Initialize-AzTimer` (Az context timer — `runspace.Open()` + first eventing call ~200ms, moved off the load path). Guarded by `$global:ProfileDeferredDone`. These are the interactive tools needed immediately after the prompt appears.
3. **Phase 2b (next idle)**: `Initialize-DeferredProfileSecondary` registers the az + zellij native tab-completers and loads git-completion (+ `g` alias completer) and WinGet CommandNotFound. Guarded by `$global:ProfileDeferredSecondaryDone`. Split from 2a so the first keypress isn't blocked by their import cost.
4. **Phase 3 (async runspace)**: Az context refresh on a 60s timer. The timer is created in Phase 2a (`Initialize-AzTimer`); the refresh itself runs in a background runspace wired up in `Set-Prompt.ps1`.

When adding to the profile, classify by cost first — anything that loads .NET assemblies or scans the filesystem belongs in Phase 2, not Phase 1. Use the `$global:ProfileModules` cache rather than calling `Get-Module -ListAvailable` again.

## Prompt architecture (`Set-Prompt.ps1`)

- **Git is synchronous** — uses 3 git processes per prompt (`rev-parse` combined, `rev-list`, `status --porcelain`). The combined `rev-parse --abbrev-ref HEAD --git-dir --git-common-dir` doubles as the "are we in a repo" gate and detects worktrees (when git-dir ≠ git-common-dir).
- **jj (Jujutsu) takes precedence over git** (`Get-JjPromptInfo`, toggle `ShowJj`). The gate is `Find-JjRoot` — a pure filesystem walk up to a `.jj` dir, so non-jj dirs spawn no jj process and the found dir doubles as the truncate-to-repo anchor. When a jj repo is detected the git segment is skipped entirely (avoids git's detached-HEAD noise in colocated repos). Inside a jj repo it runs up to 3 jj processes (`@` info template, closest-bookmark name, bookmark→@ distance), all with `--ignore-working-copy` so the prompt never snapshots the working copy. **Tradeoff:** `FileCount` and the empty (`∅`) flag therefore reflect the *last* snapshot jj took, not un-snapshotted editor edits. Segment renders as `jj:<change-id> <closest-bookmark> ↑<dist> *<files> ∅ ✎` (`∅` = empty, `✎` = no description, `!` = conflict).
- **Az context is async** via a long-lived background runspace, refreshed every 60s by a `System.Timers.Timer`. The timer's `Elapsed` handler runs in a separate runspace and cannot see main-session functions, so it bridges back via `New-Event 'Profile.AzRefreshRequested'` → `Register-EngineEvent` (which *does* run in the main session and can call `Start-AzContextRefresh`). Don't try to call session functions directly from `Register-ObjectEvent -Action`. **`Initialize-AzTimer` is defined in `Set-Prompt.ps1` but called from Phase 2a** (not at profile load) — `runspace.Open()` plus the first eventing call cost ~200ms blocking; deferring it to first idle keeps startup fast, at the cost of the ☁ segment appearing one idle later. Its `PowerShell.Exiting` cleanup handler is registered inside `Initialize-AzTimer` for the same reason.
- **Idempotency**: every event registration unregisters prior subscribers first so `. $PROFILE` reloads don't stack handlers. `Get-EventSubscriber -SourceIdentifier` does **not** support wildcards — filter with `Where-Object`. `-SupportEvent` subscribers are hidden and require `-Force` to find.
- **`$?` / `$LASTEXITCODE` must be captured on the first two lines of `prompt`** before any other command runs, and `$LASTEXITCODE` is restored at the end so git calls inside the prompt don't leak a non-zero exit to the user's next command.
- Constants (ANSI escapes, admin check, length limits) are computed once into `$global:PromptConst`; the prompt body uses a `StringBuilder`.
- Emits Windows Terminal OSC 9;9 for CWD tracking when on a filesystem provider, and syncs `[System.Environment]::CurrentDirectory` so Zellij opens new panes in the current directory (see the Zellij section).
- **zoxide recording is driven by the prompt, not by zoxide's hook.** Zoxide is initialised with `zoxide init powershell --hook none` (Phase 2a), so it does *not* wrap `$function:prompt`. The default wrapper detaches on `. $PROFILE` (Phase 1 redefines the prompt and the deferred-once guard blocks re-wrapping), which silently stops recording. Instead the prompt records the directory itself inside the filesystem-provider block (mirroring zoxide's `__zoxide_hook`: dedup on `$global:__zoxide_oldpwd`, `zoxide add` only when it changed) — survives reloads, and the line-end `$LASTEXITCODE` restore undoes the exit code `zoxide add` leaves behind. It self-guards on `$function:__zoxide_pwd` (defined only with `--hook none`) so it no-ops until Phase 2a initialises zoxide.

## Git configuration

Files live under `git/`: `gitconfig` (base), `gitconfig-work` (work overrides), `gitignore`, `gitmessage`, `templates/hooks/`.

- `core.hooksPath = ~/.git_templates/hooks` — global hook directory, so `prepare-commit-msg` runs on every repo. Branches like `feature/PROJ-123-foo` get `[PROJ-123]-` prepended to commit messages; the skip list (`master`, `develop`, `staging`, deploy/*) is in the hook.
- `init.templatedir = ~/.git_templates` — new repos inherit the hooks too.
- `init.defaultBranch = main`, `pull.ff = only`, `push.autoSetupRemote = true`, `rebase.autoStash = true`, `rebase.updateRefs = true` (stacked branches), `rerere.enabled = true`.
- Pager and diff filter are **delta** (`core.pager = delta`, `interactive.diffFilter = delta --color-only`).
- `url."git@github.com:".insteadOf` rewrites both `https://github.com/` and the `gh:` shorthand to SSH.
- **Identity**: base `gitconfig` sets personal `[user]` (`justin@puah.dev`). Work identity is applied per-repo via `[includeIf "hasconfig:remote.*.url:*hollard*"]` which includes `gitconfig-work` (sets `justin.puah@hollard.com.au` + `diff.tool = delta`). Requires Git 2.36+. For local-only work repos without a remote, run `git config user.email justin.puah@hollard.com.au` manually.
- **Installer**: `setup.ps1/setup.sh -Module git` installs `~/.gitconfig` and `~/.gitconfig-work` as git `[include]` stubs pointing to the repo files (cross-volume safe, always live), then junctions `~/.git_templates` → `git/templates/`.

## Claude Code + Codex integration

Codex CLI is wired in as a **read-only second-opinion reviewer** for Claude Code (Claude is the primary driver; the integration is one-way, Claude → Codex). See `codex/README.md` for the full design.

- **MCP reviewer**: registered at **user scope** (in `~/.claude.json`, not a tracked file — `settings.json` can't hold `mcpServers`). `setup.ps1 -Module codex` runs `claude mcp add --scope user codex -- codex mcp-server -c sandbox_mode=read-only -c approval_policy=never`. The `-c` overrides pin the reviewer read-only/non-interactive regardless of `~/.codex/config.toml`.
- **Two postures, one config**: `codex/config.toml` sets the **standalone** posture (`workspace-write` + `on-request`) for when you run `codex` directly; the MCP registration overrides to **read-only/never** for the reviewer path.
- **Shared conventions**: `claude/AGENTS.md` installs to both `~/.claude/AGENTS.md` (imported by `CLAUDE.md`) and `~/.codex/AGENTS.md`, so both tools obey the same rules. Codex also concatenates a repo's own `AGENTS.md` on top — that's the layering point for work overlays (`codex/templates/work-AGENTS.md`).
- **Trigger**: review is **on-demand only** — the `/codex-review` skill, or Claude *offers* a second opinion after a change but never calls Codex or applies findings without approval (see `claude/CLAUDE.md` → "Codex second opinion"). Auth is `codex login` (interactive, run once).

## Conventions

- **EditorConfig**: 2-space default, LF, UTF-8, trim trailing whitespace, final newline. Overrides: 4-space for `*.sh`/`*.bash*`, `git*`/`.git*`, and `*.ps1`/`*.psd1`/`*.psm1`.
- **Commit style**: imperative, sometimes `feat:` / `fix:` prefixed (`feat: Refactor Set-Prompt.ps1 for async Azure and Git support`). Stay consistent with the surrounding files' recent history.
- **PowerShell**: target pwsh 7 (`#Requires -Version 7`), Vi edit mode, custom Vi cursor handler (`OnViModeChange` toggles `` `e[1 q `` ↔ `` `e[5 q ``), `Ctrl+Oem4` (left bracket) for `ViCommandMode` — see [PSReadLine #906](https://github.com/PowerShell/PSReadLine/issues/906#issuecomment-916847040).

## Neovim (`nvim/`)

Modular Lua config targeting Neovim 0.12+. Uses `vim.pack` (Neovim 0.12 built-in package manager) — no external plugin manager. LSP is configured via the native `vim.lsp.config` / `vim.lsp.enable` API (not the lspconfig Lua framework).

Load order: `performance` → `user` → `plugins` → `options` → `keymaps` → `autocmds` → `treesitter` → `lsp` → `gitsigns` → `ui`

The `vim/` directory (Vimscript setup) is the older Vim config — kept as the Linux fallback, not the active Neovim config. `vim/vimrc` is the vimrc; Vim finds it automatically at `~/.vim/vimrc` (Linux) or `~/vimfiles/vimrc` (Windows).

### Key decisions (do not reverse without asking)

- **Plugin manager**: `vim.pack` (Neovim 0.12 built-in). `vim.pack.add(specs, { load = true, confirm = false })` in `plugins.lua` — installs in parallel on first launch, writes a lock file to `nvim/nvim-pack-lock.json`. Plugins stored in `nvim-data/site/pack/core/opt/`. Do not revert to `ensure_plugin()` or a third-party manager.
- **Treesitter branch**: `nvim-treesitter` (and `-textobjects`) are **pinned to `master`** in `plugins.lua` (`{ src = …, version = 'master' }`). Upstream archived the repo (2026-04) and made `main` the default — but `main` is a from-scratch rewrite that drops the `require('nvim-treesitter.configs').setup{}` module framework `treesitter.lua` relies on. Do not unpin to `main` without rewriting `treesitter.lua`. Building parsers needs a C compiler on PATH; **Zig** (`winget install zig.zig`) is used as `zig cc`. After changing `version`, vim.pack only re-checks-out on `vim.pack.update()` (a changed spec alone doesn't move an installed plugin); vim.pack also rewrites the lockfile `version` as `'master'` (quoted) on every startup — that's expected, leave it.
- **LSP API**: `vim.lsp.config` / `vim.lsp.enable` only. Do not use `require('lspconfig').xxx.setup{}`.
- **`_G.user_config`**: defined in `user.lua`, read by `lsp.lua` and `ui.lua`. Controls `profile` (`full`/`minimal`), LSP tool paths, and sunrise/sunset fallback hours for theme detection.
- **Profile system**: `NVIM_PROFILE=minimal` disables all plugins and uses a built-in colorscheme. Each module guards itself with an early return so the env var is the only thing to set.
- **Theme detection**: `ui.lua` queries OS dark/light mode (Windows registry → macOS `defaults` → GNOME `gsettings` → KDE `kreadconfig5`), falls back to `sunrise_hour`/`sunset_hour` from `user.lua`.
- **`vim.loader.enable()`**: must remain the first line of `performance.lua`.
- **Bicep filetype**: no built-in Neovim support — autocmd in `lsp.lua` registers `filetype = bicep` for `*.bicep`, only when `bicep_lsp_path` is non-empty.
- **Azure Pipelines filetype**: `autocmds.lua` sets `filetype = azure-pipelines` for `*.azure-pipelines.yml/yaml` so `azure_pipelines_ls` attaches exclusively and `yamlls` does not compete. Because that custom filetype has no Treesitter grammar of its own, `autocmds.lua` also calls `vim.treesitter.language.register('yaml', 'azure-pipelines')` so highlighting/indent fall back to the `yaml` parser — without it the buffer renders unhighlighted.
- **C# / .NET**: `roslyn.nvim` (seblyng) is the C# LSP — not OmniSharp. Configured in `lsp.lua` (`require('roslyn').setup({})` + `vim.lsp.config('roslyn', …)`), gated on `dotnet` being on PATH (no `user_config` field). Analysis scope is pinned to `openFiles` (not `fullSolution`) — a deliberate perf choice. `*.cs` is a built-in filetype, so no autocmd is needed. Testing/run/build are buffer-local keymaps (`<leader>nt/nr/nb`) in `after/ftplugin/cs.lua` that shell out to the `dotnet` CLI — no `easy-dotnet`/plugin, kept minimal on purpose. Inlay hints are off by default (`<leader>th` toggles). Prerequisite global tool: `dotnet tool install -g roslyn-language-server --prerelease` (auto-detected on PATH).
- **oil git status**: `refractalize/oil-git-status.nvim` shows per-file git status in oil's two sign columns (left = index, right = working tree). Requires oil's `win_options = { signcolumn = 'yes:2' }` (set in `ui.lua`) and `require('oil-git-status').setup()`.
- **Lockfile discipline**: `nvim/nvim-pack-lock.json` is vim.pack-managed — any `plugins.lua` change must be reflected there (launch nvim or `vim.pack.update()` to regenerate) and **committed together** with the plugin edit.
- **No per-machine variants yet**: single `init.lua` only — no `init.WORK-PC.lua`. Apply the `.<HOSTNAME>` suffix convention when machine-specific behaviour is needed.

### Install

Installed via `setup.ps1` (Windows) or `setup.sh` (Linux) at the repo root — see the Installation entry points section. The per-tool install scripts inside `nvim/` (`install.sh`, `install.ps1`, `install.py`) are an older standalone installer kept for backward compatibility.

## Zellij (`zellij/`)

Single KDL config file at `zellij/config.kdl`. Installed via `setup.ps1 -Module zellij` (Windows — junction of the whole `zellij/` dir) or `setup.sh -m zellij` (Linux — symlink of `config.kdl`).

### Key decisions (do not reverse without asking)

- **Locked-first**: `default_mode "locked"` — all input passes to the pane by default; Ctrl+g enters command mode. Do not change the default mode.
- **Default shell**: `default_shell "pwsh"`. Zellij opens new panes in the focused pane's Win32 process CWD, which pwsh's `Set-Location` does not update (only its provider location moves), so panes would open at `$HOME`. Worked around in the PowerShell profile: `Set-Prompt.ps1` sets `[System.Environment]::CurrentDirectory` each prompt (see upstream [zellij#5052](https://github.com/zellij-org/zellij/issues/5052)). Not fixable in Zellij's own config.
- **Themes**: `theme_dark "catppuccin-mocha"` / `theme_light "catppuccin-latte"`. Theme files live in `zellij/themes/` using the new semantic format (`text_unselected`, `ribbon_selected`, etc.) required by Zellij 0.40+. The old `fg`/`bg` palette format renders incorrectly — do not revert to it. Windows Terminal does not emit CSI 2031 so auto-switching does not work; use `zellij action toggle-theme` manually.
- **Color under Windows Terminal**: Zellij mishandles terminal color negotiation (truecolor fallback + OSC 11 background queries), which breaks diff/TUI colors in tools running inside it. Two workarounds are in place — `COLORTERM=truecolor` in the PowerShell profile and pinning Claude Code to a `*-ansi` theme. See `docs/zellij-windows-terminal-colors.md`.
- **Pane navigation**: `Alt+hjkl` in locked mode moves between Zellij panes (`MoveFocusOrTab` on left/right). Inside nvim, use `Ctrl+w hjkl` for window splits; at the window edge nvim falls back to `zellij action move-focus` via CLI (see `keymaps.lua`). vim-zellij-navigator and zellij-nav.nvim have been removed.
- **No layout files yet**: single `config.kdl` only. Add layouts to `zellij/layouts/` if needed.

## Yazi (`yazi/`)

Three config files: `yazi.toml` (manager/opener/preview settings), `keymap.toml` (keybinding additions via `prepend_keymap`), `theme.toml` (flavor reference). Installed via `setup.ps1 -Module yazi` (Windows — junction of the whole `yazi/` dir to `%AppData%\yazi\config\`).

### Key decisions (do not reverse without asking)

- **Junction strategy**: the entire `yazi/` dir is junctioned to `%AppData%\yazi\config\`, so `package.toml` (the `ya pkg` lock file) is version-controlled alongside the hand-written config. `plugins/` and `flavors/` are gitignored because they are downloaded content managed by `ya pkg`.
- **Editor opener**: `nvim %s` with `block = true` — yazi suspends while nvim is open. No platform split needed since nvim is on PATH everywhere.
- **Enter behaviour**: opens with the first matching `[open]` rule — text/code → nvim, everything else → OS default (`start`, `xdg-open`, `open`). Press `o` to get the interactive picker instead.
- **Theme**: `catppuccin-mocha` (dark) / `catppuccin-latte` (light) via the flavor system, matching Zellij. Run `ya pkg add yazi-rs/flavors:catppuccin-mocha` and `ya pkg add yazi-rs/flavors:catppuccin-latte` after `setup.ps1`.
- **Shell wrapper**: `y` function in the PowerShell profile wraps `yazi --cwd-file` so the shell follows yazi's final directory on quit. `yazi` still works as-is.
- **Keymap style**: defaults are kept intact; only `prepend_keymap` additions are used. Do not switch to a full `keymap` replacement.
