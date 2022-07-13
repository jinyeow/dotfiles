#!/bin/bash

scrot /tmp/screen.png
convert /tmp/screen.png -resize 20% -fill "#282828" -colorize 50% -blur 0x1 -resize 500% /tmp/lockbg.png
convert -gravity center -composite /tmp/lockbg.png ~/dotfiles/misc/Icons/Lock-icon.png /tmp/lockfinal.png
i3lock -u -i /tmp/lockfinal.png
rm /tmp/lockfinal.png /tmp/lockbg.png /tmp/screen.png
