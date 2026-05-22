# nix

[Nix](https://nixos.org) package manager and [Home Manager](https://github.com/nix-community/home-manager) configuration.

## Files

| File | Purpose |
|---|---|
| `home.nix` | Home Manager config — packages, dotfile links, bash and git setup |
| `config.nix` | Legacy Nix channel package list (`~/.config/nixpkgs/config.nix`) |
| `nrl.nix` | Work machine override (NRL) — sets work git email and hooks path |
| `null.nix` | Empty override imported on all non-NRL machines |

## How it works

`home.nix` is the main entry point for [Home Manager](https://github.com/nix-community/home-manager).
It manages packages, environment variables, dotfile symlinks, bash config, and
git config declaratively. At the bottom it conditionally imports a host-specific
override based on `/etc/hostname`:

```nix
imports = if host == "NRL-5CG1380ZN7"
  then [ ./nix/nrl.nix ]
  else [ ./nix/null.nix ];
```

`config.nix` is the older Nix channel approach (`nix-env -iA nixpkgs.myPackages`)
— predates the Home Manager setup. Now superseded by `home.packages` in `home.nix`.

## Status

These files are **not actively used** — dotfile management has moved to
`setup.ps1` / `setup.sh`. The config is kept as a reference and starting point
if Nix Home Manager is adopted again.

### Stale paths

`home.nix` references file paths from the old flat repo layout. If reactivating,
these all need updating to the current per-tool directory structure:

| Old path | Current location |
|---|---|
| `./curlrc` | `../curl/curlrc` |
| `./inputrc` | `../bash/inputrc` |
| `./ripgreprc` | `../ripgrep/ripgreprc` |
| `./tigrc` | `../tig/tigrc` |
| `./tigrc.vim` | `../tig/tigrc.vim` |
| `./tmux.conf` | `../tmux/tmux.conf` |
| `./vimrc` | `../vim/vimrc` |
| `./bashrc` | `../bash/bashrc` |
| `./bash/bash_aliases` | `../bash/bash_aliases` |
| `./profile` | `../bash/profile` |
| `./pwsh_profile.ps1` | `../powershell/Microsoft.PowerShell_profile.<HOSTNAME>.ps1` |
| `./config/direnv/direnv.toml` | `../config/direnv/direnv.toml` |
| `./gitignore` | `../git/gitignore` |

`home.stateVersion = "22.11"` — set when this config was created; update to
the current Home Manager release when reactivating.

## Not wired into the setup scripts.
