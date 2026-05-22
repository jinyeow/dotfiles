# bash

Bash shell configuration.

## Prerequisites

| Tool | Purpose | Install |
|---|---|---|
| bash 4+ | Shell | ships with Linux; `brew install bash` on macOS |
| [fzf](https://github.com/junegunn/fzf) | Required by `fzf_functions.sh` | system package manager |

## Files

| File | Installed as | Notes |
|---|---|---|
| `bashrc` | `~/.bashrc` | Main interactive shell config |
| `profile` | `~/.profile` | Login shell — sets PATH and exports |
| `inputrc` | `~/.inputrc` | GNU Readline config (applies to bash, psql, python REPL, etc.) |
| `bash_aliases` | `~/.bash_aliases` | Sourced from `bashrc` |
| `bash_profile` | `~/.bash_profile` | Login shell; sources `~/.profile` and `~/.bashrc` |
| `sensible.bash` | sourced by `bashrc` | Sane defaults (from [mrzool/bash-sensible](https://github.com/mrzool/bash-sensible)) |
| `fzf_functions.sh` | `~/.fzf_functions.sh` | Git+fzf helper functions — source from `~/.bashrc` |

## Key settings

**`inputrc`**
- Vi edit mode for all readline-enabled programs
- Case-insensitive tab completion
- Single `Tab` shows all matches (no double-tap needed)

**`sensible.bash`**
- `HISTCONTROL=ignoreboth` — no duplicate or space-prefixed entries in history
- `HISTSIZE=500000`, `HISTFILESIZE=100000`
- `shopt -s histappend checkwinsize globstar`
- `PROMPT_COMMAND` appends history after every command

**`fzf_functions.sh`** — git+fzf helpers (source from `~/.bashrc`):

| Function | Description |
|---|---|
| `fco` | Fuzzy checkout a branch or tag |
| `fco_preview` | Fuzzy checkout with commit log preview |
| `fcoc_preview` | Fuzzy checkout a specific commit with diff preview |

Requires `fzf` and `diff-so-fancy` (`npm install -g diff-so-fancy`) for commit previews.

## Install

```sh
./setup.sh -m bash   # Linux / WSL only
```

Not applicable on Windows — use the `powershell` module instead.
