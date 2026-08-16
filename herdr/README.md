# herdr

[Herdr](https://herdr.dev) is a terminal workspace manager for AI coding agents. It
tracks each pane's live agent session so you can see, at a glance, which agent is running
where. This module installs the shared `config.toml` and wires herdr's agent-state hooks
into the AI agents you have installed.

## Install

```powershell
setup.ps1 -Module herdr      # Windows
```
```bash
./setup.sh -m herdr          # Linux / WSL
```

herdr itself is installed separately (`https://herdr.dev`); the module warns if it is not
on PATH.

## What the module does

1. **Symlinks `config.toml`** to `~/.config/herdr/config.toml` (herdr uses `~/.config` on
   every platform, including Windows — it does **not** use `%APPDATA%`). Only this file is
   linked; herdr keeps its runtime state (`session.json`, `herdr.sock`, `*.log`) in the same
   directory and that must stay untracked.
2. **Wires agent integrations** by running `herdr integration install <agent>` for each AI
   agent found on PATH:
   - **claude** and **codex** on Windows and Linux.
   - **pi** on Linux/WSL only — `herdr integration install pi` reports "not supported on
     Windows", so `setup.ps1` omits it.

   These installs are **idempotent** — re-running is a no-op. herdr owns the files they
   generate (the `herdr-agent-state.ps1` hook script, `~/.codex/hooks.json`, and the hook's
   registration in each agent's settings), which is why they are not committed to this repo:
   the generated blocks carry machine-absolute paths, so regenerating them per machine keeps
   them correct. `codex/config.toml` carries `[features] hooks = true` (needed to turn on
   Codex's hook system) because that file is copied, not symlinked.

## config.toml

Only deliberate overrides live in `config.toml`; everything else stays on herdr's defaults.
Run `herdr --default-config` for the full annotated template. After editing:

```
herdr config check            # validate
herdr server reload-config    # apply to a running server
```

## Keybindings

`config.toml` adds `[keys] previous_agent` / `next_agent`, bound to `prefix+[` and
`prefix+]`, to cycle focus directly between active agent panes instead of walking the
workspace/tab/pane hierarchy.

- **Why these chords**: audited against `herdr --default-config`'s full `[keys]` table
  plus the tracked psmux (`psmux/psmux.conf`), Zellij (`zellij/config.kdl`), PowerShell
  (`powershell/Microsoft.PowerShell_profile.ps1`), and Windows Terminal
  (`windowsterminal/settings.json`) bindings. `[` and `]` are not assigned by any
  default Herdr action (`previous_tab`/`next_tab` already own `prefix+p`/`prefix+n`,
  ruling those out). Zellij's `Alt+[`/`Alt+]` (`PreviousSwapLayout`/`NextSwapLayout`)
  use a different modifier, so no collision there. This choice assumes Herdr is the
  **outer** workspace manager: Herdr's default prefix is `Ctrl+b`, and psmux
  (`psmux/psmux.conf`) keeps the tmux-compatible default of the same `Ctrl+b` prefix,
  under which `prefix+[`/`prefix+]` are already bound to `copy-mode`/`paste-buffer`
  (confirmed live via `psmux list-keys`). This repo's owner never nests multiplexers —
  no psmux inside Herdr, no Herdr inside psmux, no nesting of any kind — so the two
  apps never share a terminal at the same time and this collision is not a real
  conflict for this setup. That prefix-level ambiguity (both apps defaulting to
  `Ctrl+b`) predates this change and is out of scope here; it would affect any Herdr
  `prefix+*` binding the same way, not just this pair.
- **Order**: cycling order is Herdr's internal agent order. Not independently verified
  live in this session — only one agent pane was active (this session's own Claude
  pane, per `herdr agent list`), so a two-agent cycle could not be exercised
  end-to-end, and neither `herdr --help`/`herdr --skill` nor `herdr agent --help`
  document the traversal order for this UI-only keybinding (it isn't exposed over the
  socket API). Treat the exact order as **unverified** until confirmed with two or
  more active agents.
- **Zero or one active agents**: unverified for the same reason — no CLI/`--skill`
  documentation covers the keybinding's edge-case behavior, and this session had no
  way to drive real keypresses into the running Herdr UI to observe it directly.
  Confirm manually (`herdr server reload-config` then press the chords with two or
  more agents, one agent, and zero agents).
- **Indexed `focus_agent` bindings**: evaluated and **not added**. Herdr's own
  `--default-config` flags `alt+...` chords as unreliable ("may depend on your
  terminal/tmux setup"), and this repo already binds `alt+h/j/k/l` in Windows Terminal
  (`windowsterminal/settings.json`) and `Alt h/j/k/l` in Zellij
  (`zellij/config.kdl`) for pane focus — stacking a Windows Terminal → psmux/Zellij →
  Herdr chain on top of Alt-modified digits is a real risk on Windows, where Alt also
  triggers the native menu bar unless suppressed at each layer. `switch_tab` also
  already owns bare `prefix+1..9`, so any `focus_agent` binding needs a second
  modifier regardless. Separately, agent indices are not stable identifiers — the set
  of active agents changes as panes open and close, so a fixed-index jump can
  silently land on the wrong agent after one appears or disappears.
  `previous_agent`/`next_agent` cycling degrades gracefully to that churn; indexed
  jumps don't. Revisit if a future Herdr release documents indexed bindings as
  reliable on Windows.

## Verify

```
herdr integration status      # per-agent hook version + path
herdr config check
```
