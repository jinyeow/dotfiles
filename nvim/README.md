# Dotfiles

Personal dotfiles. Currently includes a Neovim configuration with install scripts for Linux and Windows.

## Structure

```
dotfiles/
├── README.md
├── install.sh       # Linux installer (bash)
├── install.ps1      # Windows installer (PowerShell 7+)
├── install.py       # Cross-platform installer (Python 3)
└── nvim/            # Neovim config source files
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

## Neovim

A modular Neovim configuration targeting Neovim 0.11+ using the built-in package manager and native LSP API (`vim.lsp.config` / `vim.lsp.enable`).

### Requirements

- Neovim >= 0.11
- Git
- ripgrep (`rg`) — for FZF live grep
- A [Nerd Font](https://www.nerdfonts.com/) — for diagnostic and gitsigns icons

### Install on Linux

```bash
chmod +x install.sh
./install.sh
```

### Install on Windows (PowerShell 7+)

```powershell
./install.ps1
```

> If you get an execution policy error, run:
> ```powershell
> Set-ExecutionPolicy -Scope CurrentUser -ExecutionPolicy RemoteSigned
> ```

### Install with Python (cross-platform)

```bash
python3 install.py
```

Requires Python 3.10+ and no third-party packages.

### Backup Behaviour

All installers back up any existing Neovim config before installing, using a timestamped directory:

```
~/.config/nvim.bak.20250521_143000        # Linux
%LOCALAPPDATA%\nvim.bak.20250521_143000   # Windows
```

### First Launch

On first launch Neovim will automatically clone all plugins. Treesitter parsers are then downloaded in the background. Expect a slower first startup.

### Profiles

Two profiles control what loads on startup. Switch per-session via the `NVIM_PROFILE` environment variable — no file editing needed.

| Profile | What loads |
|---|---|
| `full` (default) | Everything — plugins, LSP, treesitter, catppuccin |
| `minimal` | Options, keymaps, and autocmds only — no plugins, built-in colorscheme |

```powershell
# PowerShell — one session
$env:NVIM_PROFILE = 'minimal'; nvim

# PowerShell — permanent on this machine (add to $PROFILE)
$env:NVIM_PROFILE = 'minimal'
```

```bash
# Linux / macOS — one session
NVIM_PROFILE=minimal nvim
```

Minimal mode is useful on machines where you can't install plugins, or for a quick edit where full startup cost isn't worth it.

### Colorscheme

The theme is chosen automatically based on the OS dark/light mode setting:

| OS | Detection method |
|---|---|
| Windows | `reg query` → `AppsUseLightTheme` |
| macOS | `defaults read -g AppleInterfaceStyle` |
| Linux (GNOME) | `gsettings get … color-scheme` |
| Linux (KDE) | `kreadconfig5 --key ColorScheme` |

If OS detection fails or is not supported, the theme falls back to a configurable sunrise/sunset window (`sunrise_hour` / `sunset_hour` in `user.lua`).

| Theme | Dark | Light |
|---|---|---|
| Full profile | catppuccin-mocha | catppuccin-latte |
| Minimal profile | habamax (built-in) | lunaperche (built-in) |

### User Config

Before first launch, fill in any paths in `nvim/lua/config/user.lua`:

```lua
_G.user_config = {
  profile          = vim.env.NVIM_PROFILE or 'full', -- or set NVIM_PROFILE in shell

  bicep_lsp_path   = '', -- path to Bicep.LangServer.dll
  pwsh_bundle_path = '', -- path to PowerShellEditorServices bundle

  sunrise_hour = 6,  -- fallback dark-mode window: dark from sunset_hour
  sunset_hour  = 18, -- until sunrise_hour the next morning
}
```

Servers with empty paths are silently skipped.

### Plugins

| Plugin | Purpose |
|---|---|
| nvim-treesitter | Syntax highlighting and text objects |
| nvim-treesitter-textobjects | Function/class text objects |
| fzf + fzf.vim | Fuzzy finding (files, grep, buffers) |
| vim-fugitive | Git command wrapper |
| vim-commentary | Commenting (`gcc`) |
| vim-repeat | Better `.` repeat |
| catppuccin | Colour scheme (mocha dark / latte light — follows OS setting) |
| mini.surround | Surround text objects |
| nvim-lspconfig | LSP server definitions |
| schemastore.nvim | JSON/YAML schema catalogue |
| gitsigns.nvim | In-buffer git signs and hunk actions |
| render-markdown.nvim | In-buffer markdown rendering |

### LSP Servers

| Server | Language |
|---|---|
| jsonls | JSON |
| yamlls | YAML |
| azure_pipelines_ls | Azure Pipelines YAML |
| marksman | Markdown |
| bicep | Bicep (requires path in user.lua) |
| powershell_es | PowerShell (requires path in user.lua) |

### Filetype Detection

| Pattern | Filetype |
|---|---|
| `*.bicep` | `bicep` |
| `*.azure-pipelines.yml` / `*.yaml` | `azure-pipelines` |

### Key Keymaps

`<leader>` is `Space`.

#### General

| Key | Action |
|---|---|
| `<C-S-e>` | File explorer (netrw) |
| `<Esc>` | Clear search highlight |
| `<C-h/j/k/l>` | Window navigation |
| `<S-h>` / `<S-l>` | Previous/next buffer |
| `<C-Up/Down>` | Resize window height |
| `<C-Left/Right>` | Resize window width |

#### Editing

| Key | Action |
|---|---|
| `Y` | Yank to end of line (consistent with `C` and `D`) |
| `0` | Go to first non-blank character (remapped from `^`) |
| `jj` | Exit insert mode |
| `J` / `K` (visual) | Move selected lines down / up |
| `<` / `>` (visual) | Indent and stay in visual mode |
| `p` (visual) | Paste without overwriting the register |
| `<C-d>` / `<C-u>` | Scroll half-page, cursor centred |
| `n` / `N` | Next/prev search result, cursor centred |
| `/` | Search in very magic mode (`+`, `(`, `\|` work unescaped) |

#### Command-line

| Shortcut | Action |
|---|---|
| `:h <topic>` | Opens help in a vertical split |
| `#!!` (insert) | Expands to `#!/usr/bin/env <filetype>` |

#### FZF (full profile only)

| Key | Action |
|---|---|
| `<leader>ff` | Find files |
| `<leader>fg` | Grep in files |
| `<leader>fb` | Find buffers |
| `<leader>fc` | Find commands |
| `<leader>fl` | Find lines |

#### LSP (active when LSP is attached)

| Key | Action |
|---|---|
| `gd` | Go to definition |
| `gD` | Go to declaration |
| `gr` | Go to references |
| `gi` | Go to implementation |
| `K` | Hover docs |
| `<leader>rn` | Rename symbol |
| `<leader>ca` | Code action |
| `<leader>d` | Show diagnostics float |
| `[d` / `]d` | Previous/next diagnostic |

#### Git — Fugitive (full profile only)

| Key | Action |
|---|---|
| `<leader>gs` | Git status |
| `<leader>gc` | Git commit |
| `<leader>gp` | Git push |
| `<leader>gl` | Git log |
| `<leader>gd` | Git diff |
| `<leader>gb` | Git blame |

#### Git — Gitsigns (full profile only)

| Key | Action |
|---|---|
| `]h` / `[h` | Next/prev hunk |
| `<leader>hs` | Stage hunk |
| `<leader>hr` | Reset hunk |
| `<leader>hS` | Stage buffer |
| `<leader>hR` | Reset buffer |
| `<leader>hu` | Undo stage hunk |
| `<leader>hp` | Preview hunk |
| `<leader>hi` | Preview hunk inline |
| `<leader>hb` | Blame line (full) |
| `<leader>tb` | Toggle inline blame |
| `<leader>hd` | Diff this |
| `<leader>hD` | Diff against last commit |
| `ih` | Hunk text object |

#### Mini.surround

| Key | Action |
|---|---|
| `sa` | Add surrounding |
| `sd` | Delete surrounding |
| `sr` | Replace surrounding |
| `sf` / `sF` | Find surrounding right/left |
| `sh` | Highlight surrounding |

---

## Conventions for Adding Tools

This repo is designed to grow into a full dotfiles solution. Each tool should:

- Live in its own subdirectory (e.g. `nvim/`, `git/`, `pwsh/`)
- Be installed by the root scripts or have its own install script called from them
- Be documented in this README under its own section