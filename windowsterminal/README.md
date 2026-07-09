# windowsterminal

Windows Terminal settings.

## Files

| File | Installed to |
|---|---|
| `settings.json` | `%LOCALAPPDATA%\Packages\Microsoft.WindowsTerminal_8wekyb3d8bbwe\LocalState\settings.json` |

## What's configured

- **Theme**: Catppuccin Mocha (dark) / Catppuccin Latte (light), following the OS
  dark/light setting — consistent with fzf, nvim, and lazygit
- **Font**: CommitMono Nerd Font Mono 13pt (must be installed separately)
- **Keybindings**: vi-style pane focus (`alt+h/j/k/l`), `ctrl+c` copy,
  `ctrl+shift+v` paste, `ctrl+shift+f` find, and `ctrl+backspace` →
  `sendInput "\u0017"` (Ctrl+W). WT delivers Ctrl+Backspace as a native key
  event with a modifier that a terminal multiplexer (psmux/Zellij) drops when
  it forwards keys as a byte stream, so the shell can't distinguish it from
  plain Backspace. Emitting the bare `\u0017` byte instead — the same byte
  Ctrl+W produces — survives any multiplexer and lands on the shell's
  backward-delete-word (readline/PSReadLine/fzf all bind Ctrl+W to it)
- **Window restore**: `firstWindowPreference: persistedWindowLayout` — WT restores
  the previous session's tab/pane layout on launch; falls back to the default
  profile on a fresh install with no saved layout
- **Profiles**: PowerShell 7 (default), Windows PowerShell, Command Prompt,
  Azure Cloud Shell, Debian WSL (machine-specific — ignored if not installed)

## Prerequisites

| Tool | Install |
|---|---|
| [CommitMono Nerd Font](https://github.com/ryanoasis/nerd-fonts) | Not on winget — download `CommitMono.zip` from the [Nerd Fonts latest release](https://github.com/ryanoasis/nerd-fonts/releases/latest) and install the `*NerdFontMono-*.otf` faces per-user |

## Notes

Installed via `Copy-Dotfile` (not a junction) because Windows Terminal writes
back to `settings.json` when you change settings in the UI. After making UI
changes you want to keep, copy the file back to the repo manually:

```powershell
Copy-Item "$env:LOCALAPPDATA\Packages\Microsoft.WindowsTerminal_8wekyb3d8bbwe\LocalState\settings.json" `
    "path\to\dotfiles\windowsterminal\settings.json"
```

## Install

```powershell
.\setup.ps1 -Module windowsterminal
```

Windows-only — skipped silently on Linux.
