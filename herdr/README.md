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

## Verify

```
herdr integration status      # per-agent hook version + path
herdr config check
```
