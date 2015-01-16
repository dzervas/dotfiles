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

if [ "$HOSTNAME" = poseidon ]; then
	monitor=`xrandr | grep -i edp | cut -d " " -f 1`
	xrandr --newmode "1440x900_60.00" 106.50  1440 1528 1672 1904  900 903 909 934 -hsync +vsync
	xrandr --addmode $monitor 1440x900_60.00
# 	xrandr --output $monitor --mode 1440x900_60.00
fi

xrdb -merge "${HOME}/.Xresources"
xautolock -time 5 -locker slock -nowlocker slock -detectsleep -corners +000 -cornerdelay 2 &

# Hack to fix misbehaving Java applications
wmname LG3D

# Autostart
eval $(gpg-agent --daemon) &
eval $(ssh-agent --daemon) &
xbindkeys
thunar --daemon &
pulseaudio --start
firefox &
uxterm &
dwmstatus &
pasystray &
wpa_gui &
offlineimap > ~/.cache/offlineimap/stdout 2> ~/.cache/offlineimap/stderr &

exec /usr/local/bin/dwm > ~/.cache/dwm/stdout 2> ~/.cache/dwm/stderr
