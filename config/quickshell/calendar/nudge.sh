#!/bin/sh
# Wiggle the pointer 1px so the compositor re-sends pointer enter to the surface under it
# (Waybar loses hover after a layer surface opens/closes until the mouse moves).
p=$(hyprctl cursorpos 2>/dev/null) || exit 0
x=${p%%,*}; y=${p##* }
hyprctl dispatch "hl.dsp.cursor.move({x=$((x+1)),y=$y})" >/dev/null 2>&1
hyprctl dispatch "hl.dsp.cursor.move({x=$x,y=$y})" >/dev/null 2>&1
