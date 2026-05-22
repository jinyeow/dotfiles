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

## Key bindings (tigrc.vim)

Remaps tig's default navigation to vim keys, including `h/j/k/l` for movement
and other vim-style shortcuts. `tigrc` loads this automatically via `source ~/.tigrc.vim`.

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
