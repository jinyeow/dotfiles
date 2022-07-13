#!/usr/bin/env bash

# Switches Termite colors between solarized-dark and solarized-light
# CREATED: 28/10/2017
# UPDATED: 04/12/2017 19:26
# TODO: Expand usage to switch between multiple different themes

DAY_START=7
DAY_END=18

function echo_warn  { echo -e '\033[31mWARNING: '"$1"'\033[0m'; }

if [ "$TERM" != 'xterm-termite' ] && [ "$TERM" != 'screen' ]; then
  echo_warn "This script should only be used with Termite."
  exit 1
fi

# Assign each terminal it's own /tmp/theme-$ppid file
# Where $ppid is the terminals pid
# This allows different terminals to independently switch themes without conflicts
ppid=$(ps -o ppid= $$)
tmp_theme_dir="/tmp/switchtheme"
tmp_theme_pid="$tmp_theme_dir/theme-$ppid"

# Create the switchtheme directory if it doesn't exist
if ! [ -d "$tmp_theme_dir" ]; then mkdir -p "$tmp_theme_dir"; fi

theme=""

# On first startup
if ! [ -e "$tmp_theme_pid" ]; then
  hour=$(date +"%H")
  theme="dark"
  if [ $hour -gt $DAY_START ] && [ $hour -lt $DAY_END ]; then
    theme="light"
  fi
else
  if [ $(cat "$tmp_theme_pid") == "light" ]; then
    theme="dark"
  else
    theme="light"
  fi
fi

case $(echo $TERM) in
  xterm-termite|screen)
    terminal_config_dir="$HOME/dotfiles/config/termite"

    # Writes to termite config options+colors files
    cat "$terminal_config_dir/options" \
      "$terminal_config_dir/colors/solarized-$theme.colors" > "$terminal_config_dir/config"
    # Reloads termite config
    if which xdotool > /dev/null; then
      xdotool key control+shift+r
    else
      echo_warn "Unable to auto reload Termite config to switch colors. \
        Please reload manually with Ctrl+Shift+r."
    fi
    ;;
  # rxvt-unicode-256color)
  #   TODO: switch to specified colorscheme found in Xresources.d/colors/*
  #   TODO: introduce a --toggle option that switches between light/dark if it exists
  #   urxvt_config_dir="$HOME/dotfiles/Xresources.d"
  #   cat "$urxvt_config_dir/main.Xresources" > "$HOME/dotfiles/Xresources"
  #   cat "$urxvt_config_dir/colors/solarized-$theme.Xresources" >> "$HOME/dotfiles/Xresources"
  #   xrdb load ~/.Xresources;;
  *) echo "Invalid terminal. Use Termite." && exit 1;;
esac

# Updates the /tmp/theme file which keeps track of light/dark
echo "$theme" > "$tmp_theme_pid"

