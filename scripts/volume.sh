#!/usr/bin/env bash

#
# You can call this script like this:
# $./volume.sh up
# $./volume.sh down
# $./volume.sh mute
#

# Script modifies volume and sends a desktop notification at the same time.

VOL_STEP=5
HIGH_THRESHOLD=70
LOW_THRESHOLD=40

function get_volume {
  amixer get Master | grep '%' | head -n 1 | cut -d '[' -f 2 | cut -d '%' -f 1
}

function is_mute {
  amixer -c 1 get Master | grep 'Mono: Playback' | grep -o '\[off]'
  # amixer get Master | grep '%' | grep -oE '[^ ]+$' | grep off > /dev/null
}

function send_notification {
  # icon="/usr/share/icons/Paper/48x48/notifications/notification-audio-volume"
  icon="/usr/share/icons/Paper/48x48/status/stock_volume"
  volume=`get_volume`

  # Make the bar with the special character ─ (it's not dash -)
  # https://en.wikipedia.org/wiki/Box-drawing_character
  bar=$(seq -s "─" $(($volume / $VOL_STEP)) | sed 's/[0-9]//g')
  # Send the notification
  # dunstify -i audio-volume-muted-blocking -t 8 -r 2593 -u normal "    $bar"

  if [ $volume -ge $HIGH_THRESHOLD ]; then
    # icon="$icon-max.png"
    icon="$icon-max.png"
  elif [ $volume -gt $LOW_THRESHOLD ] && [ $volume -lt $HIGH_THRESHOLD ]; then
    icon="$icon-med.png"
  elif [ $volume -le $LOW_THRESHOLD ]; then
    icon="$icon-mute.png"
  fi

  if amixer -c 1 get Master | grep 'Mono: Playback' | grep -o '\[off]' ; then
    icon="/usr/share/icons/Paper/48x48@2x/status/stock_volume-min.png"
    bar="  Mute"
  fi

  dunstify -r 888 -i "$icon" "  $bar"
}

case $1 in
  up)
      # Set the volume on (if it was muted)
      amixer -D pulse set Master on > /dev/null
      # Up the volume (+ 5%)
      amixer -D pulse sset Master $VOL_STEP%+ > /dev/null
      send_notification
    ;;
  down)
      amixer -D pulse set Master on > /dev/null
      amixer -D pulse sset Master $VOL_STEP%- > /dev/null
      send_notification
    ;;
  mute)
      # Toggle mute
      # amixer -D pulse set Master 1+ toggle > /dev/null
      pactl set-sink-mute @DEFAULT_SINK@ toggle
      send_notification
    ;;
esac
