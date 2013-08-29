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

#/usr/bin/xscreensaver -no-splash &
xautolock -time 15 -locker "i3lock -i /media/files/Pictures/win/win-7.png -p win" -nowlocker "i3lock -i /media/files/Pictures/win/win-7.png -p win" -detectsleep -corners +000 -cornerdelay 5 &
xrdb -merge "${HOME}/.Xresources"
#exec /usr/bin/awesome -c ~/.config/awesome/rc.lua >> ~/.cache/awesome/stdout 2>> ~/.cache/awesome/stderr

# Hack to fix misbehaving Java applications
wmname LG3D

# Autostart
firefox &
skype &
uxterm &
dwmstatus &

exec dwm >> ~/.cache/dwm/stdout 2>> ~/.cache/dwm/stderr
