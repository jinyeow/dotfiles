# ripgrep

Config for [ripgrep](https://github.com/BurntSushi/ripgrep) (`rg`).

## Prerequisites

| Tool | Purpose | Install |
|---|---|---|
| ripgrep | Fast grep replacement | `winget install BurntSushi.ripgrep.MSVC` / `brew install ripgrep` |

## Files

| File | Installed as | Notes |
|---|---|---|
| `ripgreprc` | `~/.ripgreprc` | Loaded when `RIPGREP_CONFIG_PATH` points to it |

> ripgrep doesn't load `~/.ripgreprc` automatically. Set the env var:
> ```sh
> export RIPGREP_CONFIG_PATH="$HOME/.ripgreprc"   # bash
> $env:RIPGREP_CONFIG_PATH = "$HOME/.ripgreprc"   # PowerShell
> ```

## Settings

| Setting | Effect |
|---|---|
| `--hidden` | Searches hidden files and directories |
| `--follow` | Follows symbolic links |
| `--no-ignore` | Ignores `.gitignore` / `.ignore` files |
| `--glob=!{.git,...}` | Excludes `.git`, `node_modules`, `vendor`, etc. |
| `--glob=!*.lock` | Excludes lockfiles |
| `--smart-case` | Case-insensitive unless pattern contains uppercase |
| `--sort=path` | Results sorted by file path |
| `--max-columns=10000` | Truncates very long lines rather than omitting them |
| `--colors=...` | Custom colour scheme for paths, line numbers, and matches |

## Install

> Not yet wired into the setup scripts. Install manually:
> ```sh
> ln -sf "$(pwd)/ripgrep/ripgreprc" ~/.ripgreprc        # Linux
> copy ripgrep\ripgreprc $env:USERPROFILE\.ripgreprc    # Windows
> ```
