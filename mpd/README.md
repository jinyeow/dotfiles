# mpd

Config for [Music Player Daemon](https://www.musicpd.org) (mpd).

## Files

| File | Notes |
|---|---|
| `mpd.conf` | Main config (PulseAudio output) |
| `mpd.conf.alsa_no_pulse` | Alternative config for ALSA without PulseAudio |

## Notes

Linux only. Typically paired with `ncmpcpp` as the client — see `ncmpcpp/`.

> **Not wired into the setup scripts.** Install manually by copying the
> appropriate config to `~/.config/mpd/mpd.conf` or `~/.mpd/mpd.conf`
> depending on your mpd version and XDG setup.
