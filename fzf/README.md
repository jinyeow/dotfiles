# fzf

Config for [fzf](https://github.com/junegunn/fzf).

## Files

| File | Loaded via | Notes |
|---|---|---|
| `fzfrc` | `$env:FZF_DEFAULT_OPTS_FILE` | Base layout/binding options |

Color theme (catppuccin mocha/latte) is set dynamically in `$env:FZF_DEFAULT_OPTS`
by the PowerShell profile based on the OS dark/light setting — mirrors nvim.

## Settings

| Setting | Effect |
|---|---|
| `--layout=reverse` | Prompt at top, results below |
| `--border=rounded` | Rounded border around the popup |
| `--info=inline-right` | Match count shown at right of prompt |
| `--scroll-off=3` | Keep 3 lines of context when scrolling |
| `--highlight-line` | Highlight the full current line |
| `--wrap` | Wrap long lines instead of truncating |
| `--bind=ctrl-a:select-all` | Select all matches |
| `--bind=?:toggle-preview` | Toggle preview pane |

## Install

`$env:FZF_DEFAULT_OPTS_FILE` and `$env:RIPGREP_CONFIG_PATH` are set in
`powershell/Microsoft.PowerShell_profile.ps1` pointing directly at the repo
files — no copy needed, changes are live immediately.
