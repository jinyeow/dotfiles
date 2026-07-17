# bat

Config for [bat](https://github.com/sharkdp/bat).

## Files

| File | Loaded via | Notes |
|---|---|---|
| `config` | `$env:BAT_CONFIG_PATH` | Style and rendering options |

Color theme (Catppuccin Mocha/Latte) is set dynamically via `$env:BAT_THEME` by
the PowerShell profile based on the OS dark/light setting — mirrors nvim/fzf/tig.
`$env:DELTA_FEATURES` is set alongside it, so [delta](../git/README.md) (git's
pager/diff filter) switches its own Catppuccin syntax theme in lockstep — see
`[delta "dark-mode"]` / `[delta "light-mode"]` in `git/gitconfig`.

## Catppuccin theme provisioning

bat does not ship the Catppuccin themes the profile selects — without them, bat
warns (`unknown theme 'Catppuccin Mocha'`) and silently falls back to its
default. `setup.ps1 -Module bat` (`Install-Bat` / `Install-BatCatppuccinTheme`)
provisions them automatically when `bat` is on PATH:

1. Resolves bat's user theme directory via `bat --config-dir`.
2. Downloads `Catppuccin Mocha.tmTheme` and `Catppuccin Latte.tmTheme` from the
   official [catppuccin/bat](https://github.com/catppuccin/bat) repo's `themes/`
   directory into that directory, skipping any theme file already present.
3. Runs `bat cache --build` once, only if a theme was newly downloaded.

Honors `-DryRun` (prints what it would download/rebuild, changes nothing) and
`-Backup` (theme files are fetched content, not tracked in the repo, so the
reverse live-to-repo sync has nothing to pull back — skipped entirely). The
download fails open: a blocked or offline network prints a warning and moves on
without aborting the rest of `-Module all` — bat keeps warning and falling back
to its default theme until the module is re-run somewhere with network access.

### Manual fallback

If the automatic download fails (offline machine, blocked GitHub), install the
themes by hand:

```sh
mkdir -p "$(bat --config-dir)/themes"
curl -Lo "$(bat --config-dir)/themes/Catppuccin Mocha.tmTheme" \
  "https://raw.githubusercontent.com/catppuccin/bat/main/themes/Catppuccin%20Mocha.tmTheme"
curl -Lo "$(bat --config-dir)/themes/Catppuccin Latte.tmTheme" \
  "https://raw.githubusercontent.com/catppuccin/bat/main/themes/Catppuccin%20Latte.tmTheme"
bat cache --build
```

On Windows (PowerShell):

```powershell
$dir = Join-Path (bat --config-dir) 'themes'
New-Item -ItemType Directory -Path $dir -Force | Out-Null
Invoke-WebRequest -Uri 'https://raw.githubusercontent.com/catppuccin/bat/main/themes/Catppuccin%20Mocha.tmTheme' -OutFile (Join-Path $dir 'Catppuccin Mocha.tmTheme')
Invoke-WebRequest -Uri 'https://raw.githubusercontent.com/catppuccin/bat/main/themes/Catppuccin%20Latte.tmTheme' -OutFile (Join-Path $dir 'Catppuccin Latte.tmTheme')
bat cache --build
```

## Install

```sh
./setup.ps1 -Module bat   # Windows
```

No Linux `setup.sh` module yet — `bat` is Windows-only in the module list (see
root `CLAUDE.md`).
