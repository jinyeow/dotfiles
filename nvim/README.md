# nvim

Modular Neovim configuration targeting Neovim 0.12+ using the built-in package
manager (`vim.pack`) and native LSP API (`vim.lsp.config` / `vim.lsp.enable`).

## Prerequisites

| Tool | Purpose | Install |
|---|---|---|
| Neovim 0.12+ | Editor | `winget install Neovim.Neovim` / system package manager |
| Git | Plugin auto-install | — |
| [ripgrep](https://github.com/BurntSushi/ripgrep) | fzf-lua live grep | `winget install BurntSushi.ripgrep.GNU` |
| A [Nerd Font](https://www.nerdfonts.com/) | Diagnostic and gitsigns icons | — |
| [tree-sitter CLI](https://github.com/tree-sitter/tree-sitter) | Compiles nvim-treesitter (`main`) parsers via `tree-sitter build` | `winget install tree-sitter.tree-sitter-cli` |
| [Zig](https://ziglang.org/) | The C compiler for Treesitter parsers (via the `nvim/zigcc.cmd` shim), orgmode's org grammar, and the offline installer | `winget install zig.zig` |
| .NET SDK + roslyn-language-server | C# LSP (optional, only if editing C#) | `dotnet tool install -g roslyn-language-server --prerelease` |

## Structure

```
nvim/
├── init.lua
├── Install-PluginsOffline.ps1  # provision without github.com (see Offline install)
├── install.sh         # standalone Linux installer (legacy)
├── install.ps1        # standalone Windows installer (legacy)
├── install.py         # standalone cross-platform installer (legacy)
├── after/ftplugin/
│   ├── cs.lua         # buffer-local C# test/run/build + inlay-hint toggle
│   └── ps1.lua        # buffer-local PowerShell debug keymaps (nvim-dap)
└── lua/config/
    ├── performance.lua
    ├── user.lua
    ├── plugins.lua
    ├── options.lua
    ├── keymaps.lua
    ├── autocmds.lua
    ├── treesitter.lua
    ├── orgmode.lua    # agenda + capture templates (task / PBI / journal)
    ├── lsp.lua
    ├── dap.lua        # PowerShell debugging via PSES (DebugServiceOnly + pipe)
    ├── gitsigns.lua
    └── ui.lua
```

Load order: `performance` → `user` → `plugins` → `options` → `keymaps` →
`autocmds` → `treesitter` → `orgmode` → `lsp` → `dap` → `gitsigns` → `ui`

## Install

```powershell
# Windows
.\setup.ps1 -Module neovim

# Linux / WSL
./setup.sh -m neovim
```

The standalone scripts (`install.sh`, `install.ps1`, `install.py`) in this
directory are kept for backward compatibility.

### Offline install (`github.com` blocked)

`vim.pack` installs plugins by cloning from `github.com`. Where that host is
blocked but `codeload.github.com` (the ZIP host) is reachable, run this **on the
blocked machine**, after the dotfiles are present:

```powershell
.\Install-PluginsOffline.ps1          # add -Verbose for per-item progress
```

It provisions three things without ever touching `github.com`:

> ⚠️ **Parser step is out of date for the `main` migration.** The parser and org-grammar
> steps drive nvim-treesitter's old `master` local-compile path (they read the removed
> `ensure_installed` and don't use the `tree-sitter` CLI); they need reworking before this
> script is usable on `main`. The plugin-staging step still works. See root `CLAUDE.md`.

| | Source of truth | Fetched from |
|---|---|---|
| Plugins | `nvim-pack-lock.json` (pinned revs) | codeload ZIP → `<data>/site/pack/core/opt/<name>` |
| Treesitter parsers | `treesitter.lua`'s parser list + nvim-treesitter's `lockfile.json` | codeload → compiled locally |
| Org grammar | the version pinned in orgmode's own `install.lua` | codeload → compiled by orgmode from the local path |

The org grammar is a separate step because orgmode bypasses nvim-treesitter and
clones its own grammar — the parser step doesn't cover it.

Rev-aware and idempotent: re-run after a lockfile change to update; anything
already current is skipped. Needs a C compiler (`winget install zig.zig`); the
Treesitter-parser step additionally needs the `git` **executable** on PATH
(nvim-treesitter refuses to install without it, though no network is used).

### Backup behaviour

All installers back up any existing config before installing:
```
~/.config/nvim.bak.20250521_143000        # Linux
%LOCALAPPDATA%\nvim.bak.20250521_143000   # Windows
```

## First launch

Neovim clones all plugins automatically on first launch. Treesitter parsers
download in the background. Expect a slower first startup.

## Profiles

| Profile | What loads | How to set |
|---|---|---|
| `full` (default) | Plugins, LSP, treesitter, catppuccin | `$env:NVIM_PROFILE = 'full'` |
| `minimal` | Options, keymaps, autocmds only | `NVIM_PROFILE=minimal nvim` |

Minimal mode is useful on machines where you can't install plugins, or for
quick edits where full startup cost isn't worth it.

## User config

Edit `lua/config/user.lua` before first launch to set machine-specific paths:

```lua
_G.user_config = {
  profile          = vim.env.NVIM_PROFILE or 'full',
  bicep_lsp_path   = '', -- path to Bicep.LangServer.dll
  pwsh_bundle_path = '', -- path to PowerShellEditorServices bundle
  sunrise_hour     = 6,
  sunset_hour      = 18,
}
```

LSP servers with empty paths are silently skipped.

## Colorscheme

Theme is chosen automatically from the OS dark/light mode setting:

| OS | Detection |
|---|---|
| Windows | Registry `AppsUseLightTheme` |
| macOS | `defaults read -g AppleInterfaceStyle` |
| GNOME | `gsettings get … color-scheme` |
| KDE | `kreadconfig5 --key ColorScheme` |

Falls back to sunrise/sunset window if detection fails.

| Profile | Dark | Light |
|---|---|---|
| full | catppuccin-mocha | catppuccin-latte |
| minimal | habamax (built-in) | lunaperche (built-in) |

## Plugins

| Plugin | Purpose |
|---|---|
| nvim-treesitter | Syntax highlighting and text objects (pinned to `main` for Neovim 0.12+; builds parsers via the tree-sitter CLI + the `zigcc.cmd` zig shim) |
| nvim-treesitter-textobjects | Function/class text objects (pinned to `main`) |
| fzf-lua | Fuzzy finding (files, grep, buffers, LSP symbols); needs the fzf binary on PATH, not a vim plugin |
| vim-fugitive | Git command wrapper |
| nvim-surround | Surround text objects |
| oil.nvim | File explorer (edit the filesystem like a buffer; replaces netrw) |
| oil-git-status.nvim | Per-file git status in oil's sign columns |
| aerial.nvim | Symbol outline / code navigation |
| catppuccin | Colour scheme |
| nvim-lspconfig | LSP server definitions |
| roslyn.nvim | C# / .NET LSP (Roslyn; needs `dotnet` on PATH) |
| schemastore.nvim | JSON/YAML schema catalogue |
| gitsigns.nvim | In-buffer git signs and hunk actions |
| render-markdown.nvim | In-buffer markdown rendering |
| orgmode | Org-mode: agenda + capture. Compiles its **own** `tree-sitter-org` grammar (needs Zig) — independent of nvim-treesitter, so `org` must stay out of its `ensure_installed` |
| nvim-dap | Debug client; PowerShell adapter via PSES (needs `pwsh_bundle_path` in user.lua) |

## LSP servers

| Server | Language | Provisioned by |
|---|---|---|
| jsonls | JSON | `setup.ps1/setup.sh -Module langservers` |
| yamlls | YAML | `setup.ps1/setup.sh -Module langservers` |
| azure_pipelines_ls | Azure Pipelines YAML | `setup.ps1/setup.sh -Module langservers` |
| marksman | Markdown | Elsewhere (install manually / via package manager) |
| bicep | Bicep (requires `bicep_lsp_path` in user.lua) | Elsewhere |
| powershell_es | PowerShell (requires `pwsh_bundle_path` in user.lua) | Elsewhere |
| roslyn | C# / .NET (auto-enabled when `dotnet` is on PATH) | `dotnet tool install -g roslyn-language-server --prerelease` |

The first three are the only servers this repo provisions: the `langservers` installer module
installs them as npm packages through Volta (`vscode-langservers-extracted` supplies the JSON
server; the YAML and Azure Pipelines servers are their own packages). Their three
`vim.lsp.enable` calls are deliberately **ungated** — JSON and YAML support is baseline, not
machine-dependent, so a missing binary should produce Neovim's loud spawn-failure warning
rather than silently degrading schema validation. The remaining servers are gated on a
machine-specific prerequisite in `user.lua` (or on `dotnet`) and are installed by other means.

## Filetype detection

| Pattern | Filetype |
|---|---|
| `*.bicep` | `bicep` |
| `*.azure-pipelines.yml` / `*.yaml` | `azure-pipelines` |

The `azure-pipelines` filetype has no Treesitter grammar of its own, so `autocmds.lua` registers it against the `yaml` parser (`vim.treesitter.language.register('yaml', 'azure-pipelines')`) — highlighting and indent fall back to YAML while `azure_pipelines_ls` still attaches exclusively via the dedicated filetype.

## Key mappings

`<leader>` = `Space` (mapped to `<Nop>` on its own so a stray Space does nothing), `<localleader>` = `\`

`timeoutlen` is `1000` (Neovim's default) — there is no which-key popup whose latency a shorter value would improve. No leader mapping is a prefix of a longer one (apart from the bare `<Space>` `<Nop>` itself, which does nothing), so leader sequences are never delayed by the full timeout. Plugin operator mappings where a short form *is* a prefix of a longer one — `gc`/`gcc`, `ys`/`yss`, `yS`/`ySS` — wait the full second only if you pause mid-sequence; typing the motion resolves them immediately. `ttimeoutlen` stays at `10` so `<Esc>` remains instant.

### General

| Key | Action |
|---|---|
| `-` | File explorer (oil; `-` again goes up a dir) |
| `<Esc>` | Clear search highlight |
| `<C-h/j/k/l>` | Window navigation |
| `<S-h>` / `<S-l>` | Previous / next buffer |
| `<C-Up/Down>` | Resize window height |
| `<C-Left/Right>` | Resize window width |

### Editing

| Key | Action |
|---|---|
| `Y` | Yank to end of line |
| `0` | First non-blank character |
| `jj` | Exit insert mode |
| `J` / `K` (visual) | Move lines down / up |
| `<` / `>` (visual) | Indent and stay in visual mode |
| `p` (visual) | Paste without clobbering register |
| `<C-d>` / `<C-u>` | Scroll half-page, cursor centred |
| `n` / `N` | Next/prev search result, centred |
| `/` | Search in very magic mode |
| `#!!` (insert abbrev) | Expand to `#!/usr/bin/env <filetype>` |
| `:h <topic>` | Help in vertical split |

### fzf-lua (full profile only)

| Key | Action |
|---|---|
| `<leader>ff` | Find files |
| `<leader>fg` | Grep in files |
| `<leader>fb` | Find buffers |
| `<leader>fc` | Find commands |
| `<leader>fl` | Find lines |
| `<leader>fs` | Find LSP symbols (document) |
| `<leader>fS` | Find LSP symbols (workspace) |
| `<leader>fr` | Find recent files (MRU) |
| `<leader>fR` | Find recent files (cwd only) |
| `<leader>a` | Toggle symbol outline (aerial) |

### LSP (when attached)

| Key | Action |
|---|---|
| `gd` | Go to definition |
| `gD` | Go to declaration |
| `grr` | Go to references (0.11 built-in) |
| `gri` | Go to implementation (0.11 built-in) |
| `grn` | Rename symbol (0.11 built-in) |
| `gra` | Code action (0.11 built-in) |
| `K` | Hover docs (0.11 built-in) |
| `<leader>rn` | Rename symbol (alias) |
| `<leader>ca` | Code action (alias) |
| `<leader>d` | Diagnostics float |
| `[d` / `]d` | Previous / next diagnostic (0.11 built-in) |

### C# / .NET (in `.cs` buffers)

| Key | Action |
|---|---|
| `<leader>nt` | `dotnet test` in a terminal split |
| `<leader>nr` | `dotnet run` in a terminal split |
| `<leader>nb` | `dotnet build` in a terminal split |
| `<leader>th` | Toggle LSP inlay hints |
| `<leader>A` | Alternate source ⇄ test file (also in `.ps1` buffers) |

### PowerShell debug (in `.ps1` buffers, needs `pwsh_bundle_path`)

| Key | Action |
|---|---|
| `<F5>` | Start / continue |
| `<F10>` | Step over |
| `<F11>` / `<S-F11>` | Step into / out |
| `<S-F5>` | Terminate |
| `<leader>b` / `<leader>B` | Toggle / conditional breakpoint |
| `<leader>nr` | Toggle DAP REPL |
| `<leader>e` | Evaluate expression under cursor / selection (built-in float) |

### Org (full profile only)

Files live in `~/org/` — `inbox.org` (default notes), `work.org`, `journal.org`;
the agenda globs `~/org/**/*` (top-level *and* nested; non-org files are ignored).

The keys below are what this config's setup adds up to; for the full default keymap
(clock, dates, links, structure, agenda, text objects) see
[`docs/orgmode-cheatsheet.md`](https://github.com/jinyeow/dotfiles/blob/main/docs/orgmode-cheatsheet.md).

| Key | Action |
|---|---|
| `<leader>oa` | Open agenda |
| `<leader>oc` | Capture (then pick a template) |
| `<C-c>` | Finalise the capture (in the capture buffer) |
| `<leader>ok` | Abort the capture |
| `g?` | Help popup — context-aware (org buffer, agenda, capture, src edit) |

| Template | Key | Lands in |
|---|---|---|
| Task | `t` | `~/org/inbox.org` |
| PBI — prompts for id + title, seeds `Read acceptance criteria` / `Implement` / `PR + review` child TODOs | `p` | `~/org/work.org`, under a `* PBIs` headline |
| Journal | `j` | `~/org/journal.org`, in a year → month → day datetree |

TODO keywords are `TODO` / `NEXT` / `WAIT` → `DONE`, and `DONE` is timestamped
(`org_log_done = 'time'`).

**Setup:** `~/org/` must exist, and `work.org` must already contain a top-level
`* PBIs` headline — orgmode errors (`Refile headline "PBIs" does not exist`)
rather than creating a missing refile target.

### Fugitive (full profile only)

| Key | Action |
|---|---|
| `<leader>gs` | Git status |
| `<leader>gc` | Git commit |
| `<leader>gp` | Git push |
| `<leader>gl` | Git log |
| `<leader>gd` | Git diff |
| `<leader>gb` | Git blame |

### Gitsigns (full profile only)

| Key | Action |
|---|---|
| `]h` / `[h` | Next / prev hunk |
| `<leader>hs` | Stage hunk |
| `<leader>hr` | Reset hunk |
| `<leader>hS` | Stage buffer |
| `<leader>hR` | Reset buffer |
| `<leader>hu` | Undo stage hunk |
| `<leader>hp` | Preview hunk |
| `<leader>hb` | Blame line |
| `<leader>tb` | Toggle inline blame |
| `<leader>hd` | Diff this |
| `ih` | Hunk text object |

### nvim-surround (default keymaps)

| Key | Action |
|---|---|
| `ys{motion}{char}` | Add surrounding around motion |
| `yss{char}` | Add surrounding around the line |
| `ds{char}` | Delete surrounding |
| `cs{target}{replacement}` | Change surrounding |
| `S{char}` (visual) | Add surrounding around selection |
