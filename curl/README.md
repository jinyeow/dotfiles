# curl

Global config for [curl](https://curl.se).

## Files

| File | Installed as | Notes |
|---|---|---|
| `curlrc` | `~/.curlrc` | Applied to every curl invocation |

## Settings

| Setting | Effect |
|---|---|
| `-L` | Follow redirects |
| `connect-timeout = 60` | Timeout after 60 seconds |
| `referer = ";auto"` | Automatically set the previous URL as referer on redirect |
| `user-agent = "..."` | Custom user-agent string |
| `-k` | **Disables SSL certificate verification** — security risk as a global default |
| `-v` | Verbose output on every request — noisy as a global default |

> **Warning:** `-k` skips SSL verification for every curl call, including
> scripts and tools that invoke curl internally. Consider removing it and
> passing `-k` explicitly only when needed for local/dev endpoints.
> Similarly, `-v` will print headers and connection details for all requests.

## Install

```sh
./setup.ps1 -Module curl   # Windows
./setup.sh  -m curl        # Linux / WSL
```
