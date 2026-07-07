# psmux

Config for [psmux](https://github.com/psmux/psmux) — a **native-Windows tmux** clone
(Rust, no WSL). Adopted over Zellij for one-key pane **equalize** (`select-layout tiled`),
which Zellij has no native action for. Prefix stays the tmux default **`Ctrl+b`**.

Zellij remains installed as a fallback during the transition (see `zellij/`).

## Prerequisites

| Tool | Install |
|---|---|
| psmux | `winget install marlocarlo.psmux` (aliases: `psmux`, `pmux`, `tmux`) |
| fzf | `winget install junegunn.fzf` — for the session pickers |

## Files

| File | Installed as |
|---|---|
| `psmux.conf` | `~/.psmux.conf` (symlink) |

**psmux auto-loads `~/.psmux.conf`, not `~/.tmux.conf`** — verified: when both exist,
`.psmux.conf` wins.

## Install

```powershell
# Windows — symlinks ~/.psmux.conf, copies the vendored plugins to ~/.psmux/plugins/
# (needs Developer Mode for the symlink)
.\setup.ps1 -Module psmux
```

That's the whole install. Plugins are **vendored and SHA-pinned** in `psmux/plugins/` and copied
into `~/.psmux/plugins/` by the module — **no manual `git clone`, no PPM, no `Prefix+I`**. `psmux.conf`
loads them with plain `source-file` (this is deliberate — it avoids a namespace-hijack RCE in PPM's
resolver; see `psmux/plugins/README.md`).

## Pane layout & equalize

| Key | Action |
|---|---|
| `Prefix + Alt+5` | Tiled — force-equalize all panes into an even grid |
| `Prefix + Space` | Cycle layouts (even-h, even-v, main-h, main-v, tiled) |
| `Prefix + Alt+1..4` | even-horizontal / even-vertical / main-horizontal / main-vertical |
| `Prefix + g` | Toggle **auto-grid** live (status bar shows `auto-grid: ON/OFF`) |

**Auto-grid** (`@auto_grid on` by default) re-tiles to an even grid on *every* new pane —
2 panes = columns, 4 = 2×2 quadrants, etc. It is implemented by setting/unsetting the
`after-split-window` hook (psmux freezes an *in-hook* option condition at set time, so the
hook is toggled directly). Set `@auto_grid off` at the top of `psmux.conf` to default-disable.

## Navigation — unified `Ctrl-hjkl` (panes + nvim)

`Ctrl+h/j/k/l` moves between psmux panes **and** nvim splits with one keyset. In an nvim
pane the key is passed through to nvim (which moves its split and hands back to psmux at the
edge); elsewhere it navigates panes directly. Detection is by `#{pane_current_command}`
matching `nvim` — no `ps`/`grep`, no `$TMUX` shim.

- nvim side needs **no config change** — `nvim/lua/config/keymaps.lua` already detects
  `$TMUX` (psmux sets it) and calls `tmux select-pane` at the window edge.
- **Trade-off:** `Ctrl-l`/`Ctrl-h`/etc. are swallowed for navigation in non-nvim panes.
  `Ctrl-l` (clear screen) is recovered on **`Prefix + Ctrl-l`**.

## Sticky modes (zellij-style)

| Enter | Mode | Keys |
|---|---|---|
| `Prefix + r` | resize | `h/j/k/l` resize · `=` equalize · `Esc`/`q` exit |
| `Prefix + m` | move | `j`/`k` swap next/prev · `Space` rotate · `Esc`/`q` exit |

Move-mode is swap/rotate, **not** zellij's spatial directional move — psmux has no
`{left-of}`/`{right-of}` pane targets. With auto-grid on, the grid owns the structure and
move-mode just reorders which pane sits in which slot.

Native resize also works without a mode: `Prefix + Ctrl-arrows` (1 cell),
`Prefix + Alt-arrows` (5 cells), `Prefix + z` zoom.

## Rename

| Target | How |
|---|---|
| Session | `Prefix + $` |
| Window (tab) | `Prefix + ,` |
| Pane | `Prefix + T` — sets the pane *title* (psmux has no `rename-pane`); shown in the pane border |

## Sessions (fzf)

Shell helpers (PowerShell profile, Phase 2b — need `fzf`):

| Command | Action |
|---|---|
| `Enter-PsmuxSession` | fzf-pick a session and attach (or `switch-client` if already inside psmux) |
| `Remove-PsmuxSession` | fzf multi-select sessions to kill |
| `Get-PsmuxSession` | list session names (helper) |

Tab-completion of session names is registered for `psmux`/`pmux`/`tmux` after
`attach`/`kill-session`/`switch-client`/`has-session`.

Inside psmux, **`Prefix + s`** opens an fzf session-switcher popup (overrides the default
`choose-session`).

## Plugins

**Vendored + SHA-pinned** in `psmux/plugins/` (not fetched at runtime — see that dir's README).
Only the stateful persistence plugins are carried; theme + sensible defaults are inlined as native
`set` lines in `psmux.conf` instead of plugins.

| Plugin | Purpose |
|---|---|
| `psmux-resurrect` | Save/restore sessions (`Prefix + Ctrl-s` / `Ctrl-r`) |
| `psmux-continuum` | Auto-save (every 15m, on client-attach) + auto-restore on server start (`@continuum-restore on`; a Windows Scheduled Task is used only if `@continuum-boot on`) |

Loaded via `source-file` in `psmux.conf` — no PPM. `ppm` itself is not vendored.

Theme (catppuccin mocha), `sensible` defaults, and the prefix indicator are **inlined** in
`psmux.conf` — no plugin. The status bar shows `[grid]` when auto-grid is armed.

## Gotchas

- **No trailing inline comments on `set` lines** — psmux parses the comment as part of the
  value (`set -g @auto_grid on # ...` sets `@auto_grid` to `on # ...`). Keep comments on
  their own line.
- **Config is `~/.psmux.conf`**, not `~/.tmux.conf`.
- Persistence across a full reboot needs `psmux-resurrect` + `psmux-continuum`; the bare
  server survives detach/terminal-crash but not reboot.
