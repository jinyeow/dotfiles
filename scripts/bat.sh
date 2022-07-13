#!/bin/bash

if [ "$(pgrep dzen2)" = "" ]
then
  swidth="$(xdpyinfo | grep  -oP " dimensions: +\K[0-9]+(?=x[0-9]+.*)")"
  width="300"
  offset="40"
  y="40"
  bat0=$(acpi | grep "Battery 0" | cut -d',' -f1-2)
  bat1=$(acpi | grep "Battery 1" | cut -d',' -f1-2)
  bat_stats=" "$bat0"\n "$bat1

  echo -e "=Battery Stats=\n$bat_stats" | dzen2 -p -x "$((swidth-width-offset))" -y "$y" -w "$width" -sa "l" -l 2 -e "onstart=uncollapse,unhide" -fn "Inconsolata" -fg "#f3f3f3" -bg "#242427"
else
  killall dzen2
fi
