```
              ▄▄                         ▄▄▄▄      ██     ▄▄▄▄                         
              ██              ██        ██▀▀▀      ▀▀     ▀▀██                         
         ▄███▄██   ▄████▄   ███████   ███████    ████       ██       ▄████▄   ▄▄█████▄ 
        ██▀  ▀██  ██▀  ▀██    ██        ██         ██       ██      ██▄▄▄▄██  ██▄▄▄▄ ▀ 
        ██    ██  ██    ██    ██        ██         ██       ██      ██▀▀▀▀▀▀   ▀▀▀▀██▄ 
        ▀██▄▄███  ▀██▄▄██▀    ██▄▄▄     ██      ▄▄▄██▄▄▄    ██▄▄▄   ▀██▄▄▄▄█  █▄▄▄▄▄██ 
          ▀▀▀ ▀▀    ▀▀▀▀       ▀▀▀▀     ▀▀      ▀▀▀▀▀▀▀▀     ▀▀▀▀     ▀▀▀▀▀    ▀▀▀▀▀▀  
```

## Overview
--------
This is my github repository for my dotfiles.

Author: [jinyeow](https://github.com/jinyeow)

## Installation
### Setup of WSL for Alpine with Nix
```powershell
# Enable Hyper-V (for WSL 2) and WSL features for Windows
Enable-WindowsOptionalFeature -Online -FeatureName VirtualMachinePlatform
Enable-WindowsOptionalFeature -Online -FeatureName Microsoft-Windows-Subsystem-Linux

# use WSL 2 by default
wsl.exe --set-default-version 2
```
Then install Alpine WSL from [Microsoft Store](https://www.microsoft.com/en-gb/p/alpine-wsl/9p804crf0395#activetab=pivot:overviewtab) or [Winget](https://docs.microsoft.com/en-us/windows/package-manager/winget/).

### Bootstrapping Nix in Alpine-WSL
------------
```bash
# Change user to root and install `sudo`
su -
apk add --no-cache sudo

# Enable group `wheel` to use `sudo` (this is convention)
echo '%wheel ALL=(ALL) ALL' > /etc/sudoers.d/wheel

# Add user to the `wheel` group
adduser <USERNAME> wheel

# Set password for your user. Not set by default in Alpine-WSL
passwd <USERNAME>

# Return to original user shell
exit

# Other pre-requisites for Nix
sudo apk add --no-cache curl xz

# Fetch and execute `nix` install script
# Single-user installation of Nix
sh <(curl -L https://nixos.org/nix/install) --no-daemon

# The install script asks you to do the following (there may be differences based on the OS you use):
echo ". /home/<USERNAME>/.nix-profile/etc/profile.d/nix.sh" >> ~/.profile
```

### Installing Home Manager
[Standalone installation](https://rycee.gitlab.io/home-manager/index.html#sec-install-standalone)
```bash
nix-channel --add https://github.com/rycee/home-manager/archive/master.tar.gz home-manager
nix-channel --update

On non-NixOS, you may have to add:
export NIX_PATH=$HOME/.nix-defexpr/channels:/nix/var/nix/profiles/per-user/root/channels${NIX_PATH:+:$NIX_PATH}

nix-shell '<home-manager>' -A install

# Install `git` and `ssh` so we can fetch dotfiles from the web
nix-env -i git openssh
```

### Installation of dotfiles
------------
#### Pre-requisites
1. Setup SSH keys and add them to GitHub ssh keys

#### Setup
```bash
# Clone dotfiles repository
$ git clone git@github.com:jinyeow/dotfiles.git $HOME/dotfiles

# Move into dotfiles directory.
$ cd $HOME/dotfiles

# Remove default created `home.nix` configuration and replace with the our custom one
ln -s $(pwd)/home.nix $HOME/.config/nixpkgs/home.nix

# Install everything as specified in config (move any existing config files to *.backup versions)
home-manager switch -b backup

# To set `fish` as the login shell (if that is your `$SHELL`)
cd ~
sudo echo "$(pwd)/.nix-profile/bin/fish" >> /etc/shells
chsh -s $(pwd)/.nix-profile/bin/fish
```

## TODO
----
* [ ] Setup Home Manager for dotfiles/packages
* [ ] Combine 'bootstrap.sh' and 'dotfiles-setup.sh' into a single install.sh
* [ ] Clean up dotfiles, remove unused, update as needed
* [ ]Add to 'dotfiles-setup.sh' (or the combined one) to mv/backup the existing dotfile (if it exists) BEFORE doing a symlink
* [ ] Add WINDOWS version using PowerShell

Linux Laptop Setup Description
-----------------
* Bar `polybar`
* Browser `firefox`
* Compositor `compton`
* Editor: `(Neo)vim`
* File Manager: `ranger`
* Fonts: `Hack, Source Code Pro`
* icon fonts: `FontAwesome, ttf-ancient-fonts`
* IRC client: `weechat`
* Launcher: `rofi`
* Music player `ncmpcpp+mpd`
* Notifications: `dunst`
* OS: `archlinux`
* Shell: `zsh+zplug`
* Terminal: `alacritty, termite, urxvt`
* WM: `bspwm`

Installation (old)
------------
```bash
# Clone repo.
$ git clone https://www.github.com/jinyeow/dotfiles $HOME/dotfiles
# Move into dotfiles directory.
$ cd $HOME/dotfiles
# Install official arch packages.
$ make install
# Install packages from AUR.
$ make aur
# Symlink configuration files.
$ make init
```

Packages Installed
------------------
There are four files that contain a list of arch packages:

  1. dotfiles/archlinux/all_pac_list
  2. dotfiles/archlinux/pac_list
  3. dotfiles/archlinux/aur_list
  4. dotfiles/lists/arch_packages.txt

**all_pac_list** and **arch_packages.txt** contain all arch packages installed.

**pac_list** contains only packages from the official arch repository.

**aur_list** contains only packages from the AUR.

#### Packages that require editing the PKGBUILD and the specific flavor of urxvt
| Package | Link                                                                    | Edit PKGBUILD?   | Changes?                                                              |
| ------- | ----                                                                    | :--------------: | --------                                                              |
| termite | https://github.com/autrimpo/termite/tree/ranger-fix                     | yes              | source=(git://github.com/autrimpo/termite.git#branch=ranger-fix)      |
| urxvt   | https://aur.archlinux.org/packages/rxvt-unicode-cvs-patched-wideglyphs/ | no               |                                                                       |

Rbenv
-----
Remember to symlink `rbenv/default-gems` to `$RBENV_PATH/default-gems`.

Use rbenv to install and set ruby version.

Do not set to 'system' as it requires root to install gems.

Solutions to Miscellaneous Issues
---------------------------------
`cat misc/troubleshooting.md`

[!] Note: If using BSPWM, Burpsuite does not render correctly. To fix:

    - append the line 'export _JAVA_AWT_WM_NONREPARENTING=1' in
    /etc/profile.d/jre.sh.
    - then logout and log back in.
