#!/bin/sh
#
# ~/.xinitrc
#
# Executed by startx (run your window manager from here)

if [ -d /etc/X11/xinit/xinitrc.d ]; then
  for f in /etc/X11/xinit/xinitrc.d/*; do
    [ -x "$f" ] && . "$f"
  done
  unset f
fi

[[ -f ~/.Xresources ]] && xrdb -merge ~/.Xresources

# load Xmodmap
if [ -s ~/.Xmodmap ]; then
  xmodmap ~/.Xmodmap
fi

# autocutsel to synchronize PRIMARY and CLIPBOARD selections
if which autocutsel >/dev/null ; then
  autocutsel -fork &
  autocutsel -selection PRIMARY -fork &
fi

# compositor
if which compton >/dev/null ; then
  compton -bGf
fi

# load desktop background
# sh ~/.fehbg &
if which nitrogen >/dev/null ; then
  nitrogen --restore &
fi

# set the cursor
if which xsetroot >/dev/null ; then
  xsetroot -cursor_name left_ptr &
fi

# lock screen
# xautolock corners -0-- -time 10 -locker ~/scripts/lock &
if which xautolock >/dev/null ; then
  xautolock -corners -0-- -time 10 -locker ~/scripts/locker.sh &
fi

# start dropbox
# /usr/bin/dropbox &
# dropbox-cli start
if which dropbox >/dev/null ; then
  dropbox &
fi

# hides cursor after x seconds
if which unclutter >/dev/null ; then
  unclutter -b --ignore-scrolling
fi

# gnome-keyring
eval $(/usr/bin/gnome-keyring-daemon --start --components=pkcs11,secrets,ssh)
export SSH_AUTH_SOCK

# NetworkManager
if which nm-applet >/dev/null ; then
  nm-applet &
fi

# Redshift
# redshift-gtk &
if which redshift >/dev/null ; then
  pgrep redshift-gtk &> /dev/null || redshift-gtk -l 33.44:151 &> /dev/null &
fi

# Caffeine to prevent screen sleep during watching videos in FF
if which caffeine >/dev/null ; then
  caffeine &
fi

# Start pulseaudio for sound with firefox
if which pulseaudio >/dev/null ; then
  pulseaudio --start
fi

# urxvt daemon
if which urxvtd >/dev/null ; then
  urxvtd -q -o -f
  # exec urxvtc &
fi

# Start a terminal in the background. If it dies, X still lives.
if which termite >/dev/null ; then
  exec termite &
fi

# window manager
# exec i3
sxhkd -c ~/.config/sxhkd/sxhkdrc &
exec bspwm
