# ruby

Config for [RubyGems](https://rubygems.org) (`gem`).

## Files

| File | Installed as | Notes |
|---|---|---|
| `gemrc` | `~/.gemrc` | Applied to every `gem install` |

## Settings

| Setting | Effect |
|---|---|
| `gem: --no-document` | Skips generating local rdoc and ri documentation on install |

Skipping documentation saves significant install time and disk space.
Online docs (rubydoc.info) are a better reference anyway.

> `--no-rdoc` (the older flag) was deprecated in Ruby 2.6. This config
> uses the current `--no-document` equivalent.

## Install

> Not yet wired into the setup scripts. Install manually:
> ```sh
> ln -sf "$(pwd)/ruby/gemrc" ~/.gemrc        # Linux
> copy ruby\gemrc $env:USERPROFILE\.gemrc    # Windows
> ```
