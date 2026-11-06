# ripgrep

Config for [ripgrep](https://github.com/BurntSushi/ripgrep) (`rg`).

## Prerequisites

| Tool | Purpose | Install |
|---|---|---|
| ripgrep | Fast grep replacement | `winget install BurntSushi.ripgrep.GNU` / `brew install ripgrep` |

## Files

| File | Installed as | Notes |
|---|---|---|
| `ripgreprc` | Not copied on Windows | Loaded when `RIPGREP_CONFIG_PATH` points to it |

ripgrep does not load a config file on its own. On Windows, `powershell/Microsoft.PowerShell_profile.ps1`
sets `RIPGREP_CONFIG_PATH` to the repo file, so edits apply at once. On Linux, `setup.sh` has no
ripgrep step. Set the variable yourself (see Install).

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
| `--max-columns-preview` | Shows a truncated preview of lines that exceed `--max-columns` |
| `--column` | Show column number of the first match on each line |
| `--colors=...` | Custom colour scheme for paths, line numbers, and matches |

## Install

Windows: no step needed. The PowerShell profile sets `$env:RIPGREP_CONFIG_PATH` to the repo file.

Linux: set it in `~/.bashrc`:
```sh
export RIPGREP_CONFIG_PATH="$HOME/dotfiles/ripgrep/ripgreprc"
```
