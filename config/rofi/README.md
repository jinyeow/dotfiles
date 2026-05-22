# rofi

Config for [rofi](https://github.com/davatorium/rofi) — application launcher and window switcher.

## Files

| File | Notes |
|---|---|
| `config` | Old-format config (~2017) |

## Status

Linux only. The old `config` format was **removed in rofi v1.7.0 (2020)** — this
file will not work on any modern rofi installation without being converted to
the `.rasi` format first.

To migrate:
```sh
rofi -dump-config > ~/.config/rofi/config.rasi
```

> **Not wired into the setup scripts.**
