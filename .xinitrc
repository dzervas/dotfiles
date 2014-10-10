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

xrdb -merge "${HOME}/.Xresources"
xautolock -time 15 -locker slock -nowlocker slock -detectsleep -corners +000 -cornerdelay 2 &

# Hack to fix misbehaving Java applications
wmname LG3D

# Autostart
eval $(gpg-agent --daemon) &
thunar --daemon &
firefox &
uxterm &
dwmstatus &

exec dwm > ~/.cache/dwm/stdout 2> ~/.cache/dwm/stderr
