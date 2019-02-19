#!/bin/sh

# Keyboard/TouchPad hacks
setxkbmap -layout us,gr -option grp:win_space_toggle,caps:escape
xinput set-prop 'AlpsPS/2 ALPS DualPoint TouchPad' 'libinput Natural Scrolling Enabled' 1
xinput set-prop 'AlpsPS/2 ALPS DualPoint TouchPad' 'libinput Tapping Enabled' 1

# PolyBar
~/.config/polybar/launch.sh

# Autolock
xautolock -time 5 -locker 'i3lock -i ~/Pictures/lockscreen.png' &

# Wallpaper
feh --bg-center ~/Pictures/wallpaper.png
