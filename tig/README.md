# tig

Config for [tig](https://jonas.github.io/tig/) — terminal UI for git.

## Prerequisites

| Tool | Purpose | Install |
|---|---|---|
| tig | Terminal git browser | `winget install Jonas.Tig` / `brew install tig` / system package manager |

## Files

| File | Installed as | Notes |
|---|---|---|
| `tigrc` | `~/.tigrc` | Main config — sources `tigrc.vim` |
| `tigrc.vim` | `~/.tigrc.vim` | Vim-style key bindings sourced from `tigrc` |
| `tigrc-mocha` | (not installed) | Catppuccin Mocha theme — sourced via `TIGRC_USER` |
| `tigrc-latte` | (not installed) | Catppuccin Latte theme — sourced via `TIGRC_USER` |

## Settings

| Setting | Effect |
|---|---|
| `line-graphics = utf-8` | UTF-8 box-drawing chars for the branch graph |
| `refresh-mode = auto` | Auto-refresh views when the repo changes |
| `vertical-split = auto` | Side-by-side main/diff split on wide terminals |
| `show-changes = true` | Show staged/unstaged changes inline in diff view |
| `ignore-case = smart-case` | Case-insensitive search unless pattern has uppercase |

## Key bindings (tigrc.vim)

Remaps tig's default navigation to vim keys, including `h/j/k/l` for movement
and other vim-style shortcuts. `tigrc` loads this automatically via `source ~/.tigrc.vim`.

## Theme

Catppuccin Mocha (dark) and Latte (light) themes are in `tigrc-mocha` and `tigrc-latte`. Each file sources `~/.tigrc` for base settings and then applies color directives using xterm-256 values mapped from the Catppuccin palette.

Auto-switching is handled by the PowerShell profile: `$env:TIGRC_USER` is set to the repo-relative path of the appropriate theme file after reading `AppsUseLightTheme` from the Windows registry. `TIGRC_USER` completely replaces `~/.tigrc` as tig's user config, so the theme files open with `source ~/.tigrc` to pull in base settings and vim keybindings.

## gitconfig integration

The base `gitconfig` sets:
```ini
[tig]
    diff-options = --show-signature
```
This shows GPG signature information in tig's diff view.

## Install

```sh
./setup.ps1 -Module tig   # Windows
./setup.sh  -m tig        # Linux / WSL
```
