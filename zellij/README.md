# zellij

Config for [Zellij](https://zellij.dev/) — a terminal workspace / multiplexer.

## Prerequisites

| Tool | Install |
|---|---|
| zellij | `winget install zellij` / `cargo install zellij` / `brew install zellij` |

## Files

| File | Installed as |
|---|---|
| `config.kdl` | `~/.config/zellij/config.kdl` |

## Install

```sh
mkdir -p ~/.config/zellij
cp config.kdl ~/.config/zellij/config.kdl
```

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

## Theme

Catppuccin Mocha (dark) and Latte (light) are built into Zellij — no extra
files required. The config uses `theme_dark`/`theme_light` so Zellij switches
automatically when the terminal sends a CSI 2031 signal (Windows Terminal
supports this).

Manual toggle: `zellij action toggle-theme`
