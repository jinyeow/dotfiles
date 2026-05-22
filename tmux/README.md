# tmux

Config for [tmux](https://github.com/tmux/tmux) — terminal multiplexer.

## Prerequisites

| Tool | Purpose | Install |
|---|---|---|
| tmux 3.0+ | Terminal multiplexer | system package manager |
| [TPM](https://github.com/tmux-plugins/tpm) | Plugin manager | auto-installed on first launch |
| [xsel](http://www.vergenet.net/~conrad/software/xsel/) | Clipboard (Linux X11) | system package manager |

TPM and plugins are bootstrapped automatically on first tmux launch — no
manual install needed.

## Files

| File | Installed as | Notes |
|---|---|---|
| `tmux.conf` | `~/.tmux.conf` | Main config |
| `tmux_snapshot` | `~/tmux_snapshot` | Saved tmuxline statusline snapshot |

## Key settings

- `prefix` — default `Ctrl+b`
- Windows and panes numbered from 1 (matches keyboard order)
- Mouse enabled
- Vi mode for copy and status keys
- 50,000 line scrollback history
- Renumber windows automatically on close

## Key bindings

| Binding | Action |
|---|---|
| `prefix + r` | Reload `tmux.conf` |
| `prefix + h/j/k/l` | Select pane (vim directions) |
| `prefix + H/J/K/L` | Resize pane (vim directions) |
| `prefix + C-h/C-l` | Previous / next window |
| `prefix + C-p/C-n` | Previous / next window (alternate) |
| `prefix + %` / `prefix + "` | Split in current directory |
| `prefix + M-1..9` | Jump to window by number |
| `C-h/j/k/l` | Navigate panes (vim-tmux-navigator aware) |
| `C-M-l` | Clear screen (since `C-l` is used for pane nav) |
| `prefix + v` | Begin copy selection (vi mode) |
| `prefix + y` | Copy to clipboard via xsel |
| `prefix + ?` | Fuzzy search pane history (fuzzback) |
| `prefix + F` | Pick text from pane (tmux-picker) |

## Plugins

| Plugin | Purpose |
|---|---|
| tmux-resurrect | Save and restore sessions across restart |
| tmux-continuum | Auto-save sessions; auto-restore on start |
| tmux-sensible | Sane defaults |
| tmux-sidebar | Directory tree sidebar |
| tmux-fuzzback | Fuzzy search scrollback history |
| tmux-picker | Pick and paste text from any pane |
| tmux-fuzzywuzzy | Fuzzy session/window/pane switching |
| tmux-better-mouse-mode | Improved mouse scrolling |
| catppuccin/tmux | Theme (macchiato flavour) |

## Install

```sh
./setup.sh -m tmux   # Linux / WSL only
```

Not applicable on Windows directly — use WSL or Windows Terminal tabs instead.
After installing, press `prefix + I` inside tmux to install plugins.
