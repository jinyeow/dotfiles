# lazygit

lazygit config with delta pager, nvim editor, and Catppuccin theme switching.

## Files

| File | Purpose |
|---|---|
| `config.yml` | Base config — delta pager, nvim editor, nerd fonts |
| `theme-mocha.yml` | Catppuccin Mocha (dark) |
| `theme-latte.yml` | Catppuccin Latte (light) |

## Theme switching

On Windows, the PowerShell profile reads `AppsUseLightTheme` from the registry
at startup and sets `LG_CONFIG_FILE` to `config.yml,theme-mocha.yml` or
`config.yml,theme-latte.yml`. lazygit merges them in order, so the theme
overrides only the `gui.theme` keys. No manual selection needed — it follows
the OS dark/light setting, the same as fzf and nvim.

On Linux, `setup.sh` symlinks `config.yml` only. Theme switching is not wired
to the bash profile.

## Install

### Windows

No files are copied. `LG_CONFIG_FILE` is set in the PowerShell profile and
points directly at the repo. Run `setup.ps1 -Module lazygit` to verify lazygit
is installed.

```powershell
.\setup.ps1 -Module lazygit
```

### Linux / WSL

```bash
./setup.sh -m lazygit
```

Symlinks `~/.config/lazygit/config.yml` → `lazygit/config.yml`.

## Prerequisites

| Tool | Install |
|---|---|
| [lazygit](https://github.com/jesseduffield/lazygit) | `winget install JesseDuffield.lazygit` |
| [delta](https://github.com/dandavison/delta) | `winget install dandavison.delta` |
| Neovim | `winget install Neovim.Neovim` |
