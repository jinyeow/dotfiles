# curl

Global config for [curl](https://curl.se) — applied to every curl invocation.

## Files

| File | Installed as |
|---|---|
| `curlrc` | `~/.curlrc` |

## Settings

| Setting | Effect |
|---|---|
| `-L` | Follow redirects |
| `referer = ";auto"` | Automatically set the previous URL as referer on redirect |
| `connect-timeout = 30` | Abort if the connection phase takes more than 30 seconds (does not cap transfer time) |

## What was removed

| Flag | Why removed |
|---|---|
| `-k` | Disabled SSL certificate verification globally — a security risk for all curl calls, including those made by scripts and tools internally |
| `-v` | Verbose output on every request — breaks scripts that parse curl output and floods the terminal |
| `user-agent = "MSIE 9.0..."` | IE9 spoofing causes sites to return degraded or blocked responses; also hides curl's identity which breaks APIs that expect it |

Pass `-k` or `-v` explicitly on the command line when you actually need them.

## Install

```sh
./setup.ps1 -Module curl   # Windows
./setup.sh  -m curl        # Linux / WSL
```
