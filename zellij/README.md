# zellij

Config for [Zellij](https://zellij.dev/) — a terminal workspace / multiplexer.

## Prerequisites

| Tool | Install |
|---|---|
| zellij | `winget install Zellij.Zellij` / `cargo install zellij` / `brew install zellij` |

## Files

| File | Installed as |
|---|---|
| `config.kdl` | Windows: `%APPDATA%\Zellij\config\config.kdl` · Linux: `~/.config/zellij/config.kdl` |
| `themes/catppuccin-mocha.kdl` | Windows: `%APPDATA%\Zellij\config\themes\catppuccin-mocha.kdl` |
| `themes/catppuccin-latte.kdl` | Windows: `%APPDATA%\Zellij\config\themes\catppuccin-latte.kdl` |

## Install

```powershell
# Windows — junctions %APPDATA%\Zellij\config -> dotfiles/zellij/ (live, no copy)
.\setup.ps1 -Module zellij
```

```bash
# Linux / WSL — symlinks config.kdl directly
./setup.sh -m zellij
```

## Role and layout policy

psmux is the daily multiplexer; Zellij remains installed as a fallback. Keep
`auto_layout false`: new panes stay where they are split instead of being
reflowed by a swap layout.

An even-grid `swap_tiled_layout` was tested on Zellij 0.44.3 using
`default_layout "grid"` and pane-count-specific layouts. Zellij loaded the
layout definitions but did not automatically apply them to manually opened
panes, and `NextSwapLayout` did not reliably produce a clean 2×2 grid. This
remains an upstream feature request ([zellij#4936](https://github.com/zellij-org/zellij/issues/4936)).
Do not restore `default_layout` or swap-layout auto-tiling without a working
live demonstration.

## Design: locked-first

`default_mode "locked"` means all key input passes through to the running
program (nvim, shell, etc.) by default — no accidental zellij commands.

Press **Ctrl+g** to enter command mode. Most actions return to locked
automatically. Press **Ctrl+g** or **Esc** again to exit back to locked.

## Key bindings

### Always active (locked mode)

| Key | Action |
|---|---|
| `Ctrl+g` | Enter command mode |
| `Alt+h/j/k/l` | Move focus between panes (wraps to adjacent tab on left/right edges) |
| `Alt+s` | Enter scroll mode |
| `Alt+n` | New pane |
| `Alt+z` | Toggle fullscreen |
| `Alt+[` | Previous pane layout |
| `Alt+]` | Next pane layout |

### Command mode (after Ctrl+g)

#### Pane navigation & splits

| Key | Action |
|---|---|
| `h/j/k/l` | Focus pane (wraps to adjacent tab at left/right edges) |
| `-` | New pane below |
| `\` | New pane to the right |
| `x` | Close focused pane |
| `z` | Toggle pane fullscreen |
| `f` | Toggle floating panes |
| `Space` | Embed / float focused pane |
| `p` | Pin floating pane (stays visible across all tabs) |
| `c` | Rename focused pane (type name, Enter to confirm, Esc to cancel) |
| `b` | Break pane out to a new tab |
| `[` | Send pane to the tab on the left |
| `]` | Send pane to the tab on the right |

#### Tabs

| Key | Action |
|---|---|
| `n` | New tab |
| `X` | Close tab |
| `Tab` / `Shift+Tab` | Next / previous tab |
| `H` | Move current tab left |
| `L` | Move current tab right |
| `R` | Rename current tab |
| `1`–`9` | Jump to tab N |
| `0` | Jump to tab 10 |

#### Sub-modes

| Key | Enters mode | Purpose |
|---|---|---|
| `s` | scroll | Scroll scrollback; `/` to search |
| `r` | resize | Resize pane with `h/j/k/l` |
| `m` | move | Swap pane position with `h/j/k/l`; `n`/`p` to cycle |

#### Scroll mode

| Key | Action |
|---|---|
| `j/k` | Scroll down/up |
| `d/u` | Half-page down/up |
| `Ctrl+f/b` | Page down/up |
| `g/G` | Top / bottom of scrollback |
| `/` | Enter search (then `n/N` for next/prev result) |
| `e` | Open scrollback in `$EDITOR` (nvim) |

#### Session

| Key | Action |
|---|---|
| `d` | Detach session |
| `w` | Open session manager (floating) |

#### Resize mode

| Key | Action |
|---|---|
| `h/j/k/l` | Resize in direction |
| `=` / `-` | Increase / decrease overall |

## Theme

Catppuccin Mocha (dark) and Latte (light) are defined in `themes/` using the
new semantic format required by Zellij 0.40+ (`text_unselected`, `ribbon_selected`,
etc.). The old `fg`/`bg` palette format is no longer used and renders incorrectly
on newer versions.

`theme_dark`/`theme_light` auto-switch when the terminal emits a CSI 2031
dark/light signal. **Windows Terminal does not emit this signal** — toggle
manually with:

```sh
zellij action toggle-theme
```

## Default shell

`default_shell "pwsh"` — new panes open PowerShell 7. Zellij opens new panes in
the focused pane's process CWD, which pwsh's `Set-Location` does not update (only
its provider location moves), so panes would open at `$HOME`. Worked around in the
PowerShell profile: `Set-Prompt.ps1` sets `[System.Environment]::CurrentDirectory`
on each prompt render (see upstream [zellij#5052](https://github.com/zellij-org/zellij/issues/5052)).
Not fixable in Zellij's own config.

## Neovim integration

Pane navigation uses `Alt+hjkl` in locked mode. Inside nvim, use `Ctrl+w hjkl`
to move between nvim windows; at the window edge nvim calls
`zellij action move-focus` via CLI to cross into the adjacent Zellij pane.
vim-zellij-navigator and zellij-nav.nvim are not used.
