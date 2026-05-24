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

## Keybindings

### In-fzf (apply everywhere fzf is invoked)

| Key | Action |
|---|---|
| `Ctrl+a` | Select all matches |
| `?` | Toggle preview pane |

### PowerShell shell (PSFzf)

| Key | Action |
|---|---|
| `Ctrl+r` | Fuzzy reverse history search |
| `Ctrl+t` | Fuzzy file picker (insert path at cursor) |
| `Tab` | Fuzzy tab completion |
| `Alt+f` | Fuzzy ripgrep search across files |
| `Alt+b` | Fuzzy git branch switcher (`switch_git_branch`) |
| `Alt+g` | Fuzzy git worktree navigator (`cd_git_worktree`) |

PSFzf also enables these aliases: `fkill` (fuzzy kill process), `fe` (fuzzy edit), `fgs` (fuzzy git status), `fh` (fuzzy history), `fcd` (fuzzy set location).

### Bash / WSL

| Key | Action |
|---|---|
| `Ctrl+r` | Fuzzy history search (`__fzf_history`) |

### Neovim (`<leader>` = Space)

| Key | Action |
|---|---|
| `<leader>ff` | Find files (`:Files`) |
| `<leader>fg` | Grep in files (`:Rg`) |
| `<leader>fb` | Find open buffers (`:Buffers`) |
| `<leader>fc` | Find commands (`:Commands`) |
| `<leader>fl` | Find lines in loaded buffers (`:Lines`) |

## Install

`$env:FZF_DEFAULT_OPTS_FILE` and `$env:RIPGREP_CONFIG_PATH` are set in
`powershell/Microsoft.PowerShell_profile.ps1` pointing directly at the repo
files — no copy needed, changes are live immediately.
