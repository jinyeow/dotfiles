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
| [Zig](https://ziglang.org/) | C compiler for building Treesitter parsers (used as `zig cc`) | `winget install zig.zig` |
| .NET SDK + roslyn-language-server | C# LSP (optional, only if editing C#) | `dotnet tool install -g roslyn-language-server --prerelease` |

## Structure

```
nvim/
├── init.lua
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
    ├── lsp.lua
    ├── dap.lua        # PowerShell debugging via PSES (DebugServiceOnly + pipe)
    ├── gitsigns.lua
    └── ui.lua
```

Load order: `performance` → `user` → `plugins` → `options` → `keymaps` →
`autocmds` → `treesitter` → `lsp` → `dap` → `gitsigns` → `ui`

## Install

```powershell
# Windows
.\setup.ps1 -Module neovim

# Linux / WSL
./setup.sh -m neovim
```

The standalone scripts (`install.sh`, `install.ps1`, `install.py`) in this
directory are kept for backward compatibility.

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
| nvim-treesitter | Syntax highlighting and text objects (pinned to `master`; needs Zig to build parsers) |
| nvim-treesitter-textobjects | Function/class text objects (pinned to `master`) |
| fzf + fzf-lua | Fuzzy finding (files, grep, buffers, LSP symbols) |
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
| nvim-dap | Debug client; PowerShell adapter via PSES (needs `pwsh_bundle_path` in user.lua) |

## LSP servers

| Server | Language |
|---|---|
| jsonls | JSON |
| yamlls | YAML |
| azure_pipelines_ls | Azure Pipelines YAML |
| marksman | Markdown |
| bicep | Bicep (requires `bicep_lsp_path` in user.lua) |
| powershell_es | PowerShell (requires `pwsh_bundle_path` in user.lua) |
| roslyn | C# / .NET (auto-enabled when `dotnet` is on PATH) |

## Filetype detection

| Pattern | Filetype |
|---|---|
| `*.bicep` | `bicep` |
| `*.azure-pipelines.yml` / `*.yaml` | `azure-pipelines` |

The `azure-pipelines` filetype has no Treesitter grammar of its own, so `autocmds.lua` registers it against the `yaml` parser (`vim.treesitter.language.register('yaml', 'azure-pipelines')`) — highlighting and indent fall back to YAML while `azure_pipelines_ls` still attaches exclusively via the dedicated filetype.

## Key mappings

`<leader>` = `Space`, `<localleader>` = `\`

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
