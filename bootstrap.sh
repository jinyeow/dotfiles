#!/usr/bin/env bash

# Author: Jin-Yeow J Puah
# Last Updated: 28/10/17 20:26

# NOTE: use rbenv instead of RVM.
# NOTE: Run 'gem rdoc --all --ri --no-rdoc' to get ri documentation for ALL RUBY
# NOTE: To build ri documentation for Ruby and stdlib:
#       $ rdoc -a --ri-site -V --output $HOME/.rdoc
# NOTE: There may be an alternative flag to UPDATE the ri docs once built.

function print_task { printf '\033[1mTASK: '"$1"'\033[0m'; }
function print_ok { printf '\033[33m'"$1"'\033[0m'; }
function print_warn  { printf '\033[31mWARNING: '"$1"'\033[0m'; }
function print_green { printf '\e[32m\e[1m'"$1"'\e[0m'; }

# $1 is the TASK message
# $2 gives the source
# $3 gives the destination
function linker() {
  printf "    -- $1"

  if [ -f "dotfiles/$2" ]; then
    ln -s "dotfiles/$2" "$3"
    if [ -e "$3" ]; then
      print_green "done\!\n"
    else
      print_warn "[FAILED]\n"
    fi
  else
    print_warn "[FAILED]\n"
  fi
}

print_task "[*] Moving to $HOME"
cd "$HOME"

print_task "[*] Sym linking rc files and folders . . ."

# PACMAN HOOKS
print_task "  == linking pacman hooks"

if ! [ -d /etc/pacman.d/hooks ]; then
  printf "    -- creating pacman hooks directory..."
  mkdir /etc/pacman.d/hooks
  if [ -d /etc/pacman.d/hooks ]; then
    print_green "done!\n"
  else
    print_warn "FAILED.\n"
  fi
fi

linker "linking paccache hook..." dotfiles/etc/pacman.d/hooks/paccache.hook \
  /etc/pacman.d/hooks/paccache.hook
linker "linking reflector hook..." dotfiles/etc/pacman.d/hooks/reflector.hook \
  /etc/pacman.d/hooks/reflector.hook

# $HOME/.config/ DIRECTORIES
# NOTE: missing archey3.cfg, bspwm, sxhkd, dunst, rtv
#       -- these depend on if they're installed/being used or not
print_task "  == linking \$HOME/.config directories"

linker "linking config/nvim directory..." "config/nvim" "$HOME/.config/nvim"
linker "linking config/ranger directory..." "config/ranger" "$HOME/.config/ranger"
linker "linking config/redshift directory..." "config/redshift" "$HOME/.config/redshift"
linker "linking config/termite directory..." "config/termite" "$HOME/.config/termite"

# DIRECTORIES
print_task "  == linking \$HOME directories"

linker "linking scripts directory..." dotfiles/scripts $HOME/scripts
linker "linking ssh directory..." dotfiles/ssh $HOME/ssh

if which urxvt > /dev/null; then
  linker "linking urxvt directory..." dotfiles/urxvt $HOME/.urxvt
fi

# RC FILES
print_task "  == linking RC files"

linker "linking asoundrc..." dotfiles/asoundrc $HOME/.asoundrc
linker "linking ctags..." dotfiles/ctags $HOME/.ctags
linker "linking notags..." dotfiles/notags $HOME/.notags
linker "linking profile..." dotfiles/profile $HOME/.profile
linker "linking psqlrc..." dotfiles/psqlrc $HOME/.psqlrc
linker "linking vimrc..." dotfiles/vimrc $HOME/.vimrc
linker "linking warprc..." dotfiles/warprc $HOME/.warprc
linker "linking xinitrc..." dotfiles/xinirc $HOME/.xinitrc
linker "linking Xmodmap..." dotfiles/Xmodmap $HOME/.Xmodmap
linker "linking Xresources..." dotfiles/Xresources $HOME/.Xresources

if which stalonetray > /dev/null; then
  linker "linking stalonetrayrc..." dotfiles/stalonetrayrc $HOME/.stalonetrayrc
fi

# NOTE: using pacaur instead of yaourt as of 28/10/2017
# linker "linking yaourtrc..." dotfiles/yaourtrc $HOME/.yaourtrc

# NOTE: using vimfx instead of vimperator as of 28/10/2017
# linker "linking vimperatorrc..." dotfiles/vimperatorrc $HOME/.vimperatorrc

# ZSH
if which zsh > /dev/null; then
  print_task "  == linking ZSH config"
  linker "linking zsh directory..." dotfiles/zsh $HOME/.zsh
  linker "linking zlogin..." dotfiles/zlogin $HOME/.zlogin
  linker "linking zprofile..." dotfiles/zprofile $HOME/.zprofile
  linker "linking zshrc..." dotfiles/zshrc $HOME/.zshrc
fi


# TMUX
if which tmux > /dev/null; then
  print_task "  == linking TMUX config"
  linker "linking tmux_snapshot..." dotfiles/tmux_snapshot $HOME/tmux_snapshot
  linker "linking tmux.conf..." dotfiles/tmux.conf $HOME/.tmux.conf
  print_warn "[!] Note: Install TMUX Plugins with prefix + I"
fi

# GIT
print_task "  == linking git config"

linker "linking gitconfig..." dotfiles/gitconfig $HOME/.gitconfig
linker "linking gitignore..." dotfiles/gitignore $HOME/.gitignore
linker "linking template directory..." dotfiles/git_template $HOME/.git_template

print_task "    -- setting git global gitignore..."
if git config --global core.excludesfile $HOME/.gitignore > /dev/null; then
  print_green "done\!\n"
else
  print_warn "[FAILED]\n"
fi

# RUBY
if which ruby > /dev/null; then
  print_task "  == linking ruby config"

  linker "linking gemrc..." dotfiles/gemrc $HOME/.gemrc
  linker"linking pryrc..." dotfiles/pryrc $HOME/.pryrc
fi

# MPD+NCMPCPP
linker "linking mpd directory..." dotfiles/mpd $HOME/.mpd
linker "linking ncmpcpp directory..." dotfiles/ncmpcpp $HOME/.ncmpcpp

# MISC
print_task "[+] Copying synaptics configuration for touchpad to /etc/X11/xorg.conf.d/\n"
sudo cp dotfiles/50-synaptics.conf /etc/X11/xorg.conf.d/

print_warn "[!] Note: If using BSPWM, Burpsuite does not render correctly. To fix:\n \
    -- append the line 'export _JAVA_AWT_WM_NONREPARENTING=1' in \
  /etc/profile.d/jre.sh. Then logout and log back in.\n"

print_green "Finished dotfiles and miscellaneous configuration setup.\n"
