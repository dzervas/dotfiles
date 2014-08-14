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

xautolock -time 15 -locker "i3lock -i /media/files/Pictures/win/win-7.png -p win" -nowlocker "i3lock -i /media/files/Pictures/win/win-7.png -p win" -detectsleep -corners +000 -cornerdelay 5 &
xrdb -merge "${HOME}/.Xresources"

# Hack to fix misbehaving Java applications
wmname LG3D

# Autostart
eval $(gpg-agent --daemon) &
mpd
thunar --daemon &
firefox &
skype &
uxterm &
#uxterm -class mutt -e mutt &
dwmstatus &
#steam &

exec dwm > ~/.cache/dwm/stdout 2> ~/.cache/dwm/stderr
#xinput create-master Seat2
#DISPLAY=:0.0 exec dwm.seat1 >> ~/.cache/dwm/stdout1 2>> ~/.cache/dwm/stderr1 &
#DISPLAY=:0.1 exec dwm.seat2 >> ~/.cache/dwm/stdout2 2>> ~/.cache/dwm/stderr2
