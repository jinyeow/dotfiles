# zellij

Config for [Zellij](https://zellij.dev/) — a terminal workspace / multiplexer.

## Prerequisites

| Tool | Install |
|---|---|
| zellij | `winget install zellij` / `cargo install zellij` / `brew install zellij` |

## Files

| File | Installed as |
|---|---|
| `config.kdl` | Windows: `%APPDATA%\Zellij\config\config.kdl` · Linux: `~/.config/zellij/config.kdl` |

## Install

```powershell
# Windows
.\setup.ps1 -Module zellij
```

```bash
# Linux / WSL
./setup.sh -m zellij
```

On Windows this creates a directory junction `%APPDATA%\Zellij\config -> dotfiles/zellij/` so changes are live. On Linux it symlinks `config.kdl` directly.

## Design: locked-first

`default_mode "locked"` means all key input passes through to the running
program (nvim, shell, etc.) by default — no accidental zellij commands.

Press **Ctrl+g** to enter command mode. Most actions return to locked
automatically. Press **Ctrl+g** or **Esc** again to exit back to locked.

## Key bindings (command mode — after Ctrl+g)

### Panes

| Key | Action |
|---|---|
| `h/j/k/l` | Focus pane (wraps to adjacent tab at left/right edges) |
| `-` | New pane below |
| `\` | New pane to the right |
| `x` | Close focused pane |
| `z` | Toggle pane fullscreen |
| `f` | Toggle floating panes |
| `Space` | Embed / float focused pane |
| `r` | Enter resize mode |

### Tabs

| Key | Action |
|---|---|
| `n` | New tab |
| `X` | Close tab |
| `Tab` / `Shift+Tab` | Next / previous tab |
| `1`–`5` | Jump to tab N |

### Scroll & search

| Key | Action |
|---|---|
| `s` | Enter scroll mode |
| `j/k` | Scroll down/up (in scroll mode) |
| `d/u` | Half-page down/up (in scroll mode) |
| `Ctrl+f/b` | Page down/up (in scroll mode) |
| `g/G` | Top / bottom of scrollback |
| `/` | Enter search (then `n/N` for next/prev result) |
| `e` | Open scrollback in `$EDITOR` |

### Session

| Key | Action |
|---|---|
| `d` | Detach session |
| `w` | Open session manager (floating) |

### Resize mode

| Key | Action |
|---|---|
| `h/j/k/l` | Resize in direction |
| `=` / `-` | Increase / decrease overall |

## Default shell

`default_shell "pwsh"` — new panes open PowerShell 7. Known limitation: new
panes open at `$HOME` rather than the current pane's directory (upstream Zellij
bug with pwsh CWD inheritance, no workaround in config).

## Theme

Catppuccin Mocha (dark) and Latte (light) are built into Zellij — no extra
files required. The config uses `theme_dark`/`theme_light` so Zellij switches
automatically when the terminal sends a CSI 2031 signal (Windows Terminal
supports this).

Manual toggle: `zellij action toggle-theme`

## Neovim integration

Ctrl+hjkl pane navigation is handled by the
[vim-zellij-navigator](https://github.com/hiasr/vim-zellij-navigator) WASM
plugin (v0.3.0, downloaded on first use) together with
[zellij-nav.nvim](https://github.com/swaits/zellij-nav.nvim) on the Neovim
side. When the focused pane is running nvim the key is forwarded to nvim first;
at the window edge nvim hands control back to Zellij to cross panes.
