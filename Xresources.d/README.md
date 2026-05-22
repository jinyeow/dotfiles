# Xresources.d

X11 resource configuration — colours and terminal appearance for Linux.

## Files

| File / Directory | Purpose |
|---|---|
| `main.Xresources` | Entry point — `#include`s the active colour scheme and component configs |
| `colors/` | Colour scheme files (base16, gruvbox, solarized, etc.) |
| `urxvt.Xresources` | urxvt terminal settings |
| `rofi.Xresources` | Rofi launcher colour overrides |
| `rofi-colors/` | Gruvbox colour variants for rofi |

## Usage

Merge into the X server resource database:
```sh
xrdb -merge ~/.Xresources
```

`~/.Xresources` should include (or symlink to) `main.Xresources`.

## Notes

Linux / X11 only. The format remains compatible with modern xrdb — no breaking
changes to the Xresources syntax.

> **Not wired into the setup scripts.**
