```
              ▄▄                         ▄▄▄▄      ██     ▄▄▄▄                         
              ██              ██        ██▀▀▀      ▀▀     ▀▀██                         
         ▄███▄██   ▄████▄   ███████   ███████    ████       ██       ▄████▄   ▄▄█████▄ 
        ██▀  ▀██  ██▀  ▀██    ██        ██         ██       ██      ██▄▄▄▄██  ██▄▄▄▄ ▀ 
        ██    ██  ██    ██    ██        ██         ██       ██      ██▀▀▀▀▀▀   ▀▀▀▀██▄ 
        ▀██▄▄███  ▀██▄▄██▀    ██▄▄▄     ██      ▄▄▄██▄▄▄    ██▄▄▄   ▀██▄▄▄▄█  █▄▄▄▄▄██ 
          ▀▀▀ ▀▀    ▀▀▀▀       ▀▀▀▀     ▀▀      ▀▀▀▀▀▀▀▀     ▀▀▀▀     ▀▀▀▀▀    ▀▀▀▀▀▀  
```

Overview
--------
This is my github repository for my dotfiles.
Use `make` to install dotfiles and packages.

Author: [jinyeow](https://github.com/jinyeow)

Setup Description
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

Installation
------------
```bash
# Clone repo.
$. git clone https://www.github.com/jinyeow/dotfiles $HOME/dotfiles
# Move into dotfiles directory.
$. cd $HOME/dotfiles
# Install official arch packages.
$. make install
# Install packages from AUR.
$. make aur
# Symlink configuration files.
$. make init
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
