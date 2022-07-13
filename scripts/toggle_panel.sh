#!/bin/bash

# NOTE: If bar is 'floating' (has a y-offset > 0) then increase the window_gap
# until everything looks pretty.
PANEL_WM_NAME=bspwm_panel

if [ $(pgrep -cx panel) -lt 1 ] ; then
  ~/scripts/panel &>/tmp/panel.log &
  sleep 0.5
  stalonetray &

  # Sends stalonetray + lemonbar to the layer below Bspwm root so fullscreen
  # works properly
  until tray_id=$(xdo id -a stalonetray)
  do
    sleep 0.5
  done
  [ -n "$tray_id" ] && xdo above -t "$(xdo id -N Bspwm -n root | sort | head -n 1)" "$tray_id"

  until panel_id=$(xdo id -a "$PANEL_WM_NAME")
  do
    sleep 0.5
  done
  [ -n "$panel_id" ] && xdo above -t "$(xdo id -N Bspwm -n root | sort | head -n 1)" "$panel_id"
else
  killall panel
  killall stalonetray
  bspc config top_padding 0
fi
