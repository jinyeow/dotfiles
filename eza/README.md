# eza

Theme config for [eza](https://github.com/eza-community/eza), the modern `ls`.

## Files

| File | Loaded via | Notes |
|---|---|---|
| `themes/mocha/theme.yml` | `$env:EZA_CONFIG_DIR` | Catppuccin Mocha (mauve) — dark |
| `themes/latte/theme.yml` | `$env:EZA_CONFIG_DIR` | Catppuccin Latte (mauve) — light |

eza reads `theme.yml` from the directory named in `EZA_CONFIG_DIR`, so each
flavour lives in its own subdirectory. The PowerShell profile sets
`EZA_CONFIG_DIR` to the mocha or latte dir based on the OS dark/light setting
(`$_isDark`) — mirrors fzf, bat, lazygit, and tig. Mauve accent matches the fzf
prompt colour (`#CBA6F7`).

Themes are the official [catppuccin/eza](https://github.com/catppuccin/eza)
files, vendored verbatim and renamed to `theme.yml`.

## Wrappers

The profile defines `ll` / `la` / `lt` (long+git+icons, all, 2-level tree).
Native `ls` / `Get-ChildItem` is left untouched for object pipelines.

## Install

`$env:EZA_CONFIG_DIR` is set in `powershell/Microsoft.PowerShell_profile.ps1`
pointing directly at the repo — no copy needed, changes are live immediately.
Requires a Nerd Font for `--icons` glyphs (already used by the prompt).
