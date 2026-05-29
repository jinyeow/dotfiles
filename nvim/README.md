# nvim

Modular Neovim configuration targeting Neovim 0.11+ using the built-in package
manager and native LSP API (`vim.lsp.config` / `vim.lsp.enable`).

## Prerequisites

| Tool | Purpose | Install |
|---|---|---|
| Neovim 0.11+ | Editor | `winget install Neovim.Neovim` / system package manager |
| Git | Plugin auto-install | — |
| [ripgrep](https://github.com/BurntSushi/ripgrep) | FZF live grep | `winget install BurntSushi.ripgrep.MSVC` |
| A [Nerd Font](https://www.nerdfonts.com/) | Diagnostic and gitsigns icons | — |

## Structure

```
nvim/
├── init.lua
├── install.sh         # standalone Linux installer (legacy)
├── install.ps1        # standalone Windows installer (legacy)
├── install.py         # standalone cross-platform installer (legacy)
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

Load order: `performance` → `user` → `plugins` → `options` → `keymaps` →
`autocmds` → `treesitter` → `lsp` → `gitsigns` → `ui`

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
| nvim-treesitter | Syntax highlighting and text objects |
| nvim-treesitter-textobjects | Function/class text objects |
| fzf + fzf.vim | Fuzzy finding (files, grep, buffers) |
| vim-fugitive | Git command wrapper |
| vim-commentary | Commenting (`gcc`) |
| vim-repeat | Better `.` repeat |
| catppuccin | Colour scheme |
| mini.surround | Surround text objects |
| nvim-lspconfig | LSP server definitions |
| schemastore.nvim | JSON/YAML schema catalogue |
| gitsigns.nvim | In-buffer git signs and hunk actions |
| render-markdown.nvim | In-buffer markdown rendering |

## LSP servers

| Server | Language |
|---|---|
| jsonls | JSON |
| yamlls | YAML |
| azure_pipelines_ls | Azure Pipelines YAML |
| marksman | Markdown |
| bicep | Bicep (requires `bicep_lsp_path` in user.lua) |
| powershell_es | PowerShell (requires `pwsh_bundle_path` in user.lua) |

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
| `<C-S-e>` | File explorer (netrw) |
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

### FZF (full profile only)

| Key | Action |
|---|---|
| `<leader>ff` | Find files |
| `<leader>fg` | Grep in files |
| `<leader>fb` | Find buffers |
| `<leader>fc` | Find commands |
| `<leader>fl` | Find lines |

### LSP (when attached)

| Key | Action |
|---|---|
| `gd` | Go to definition |
| `gD` | Go to declaration |
| `gr` | Go to references |
| `gi` | Go to implementation |
| `K` | Hover docs |
| `<leader>rn` | Rename symbol |
| `<leader>ca` | Code action |
| `<leader>d` | Diagnostics float |
| `[d` / `]d` | Previous / next diagnostic |

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

### mini.surround

| Key | Action |
|---|---|
| `sa` | Add surrounding |
| `sd` | Delete surrounding |
| `sr` | Replace surrounding |
| `sf` / `sF` | Find surrounding right / left |
| `sh` | Highlight surrounding |
