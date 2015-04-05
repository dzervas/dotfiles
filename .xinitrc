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
xautolock -time 5 -locker slock -nowlocker slock -detectsleep -corners +000 &

# Hack to fix misbehaving Java applications
wmname LG3D

envfile="$HOME/.gnupg/gpg-agent.env"

if [[ -e "$envfile" ]] && kill -0 $(grep GPG_AGENT_INFO "$envfile" | cut -d: -f 2) 2>/dev/null; then
    eval "$(cat "$envfile")"
else
    eval "$(gpg-agent --daemon --enable-ssh-support --write-env-file "$envfile")"
fi

export GPG_AGENT_INFO  # the env file does not contain the export statement
export SSH_AUTH_SOCK   # enable gpg-agent for ssh

# Autostart
#xbindkeys
#mpd
#firefox-bin &
#thunderbird-bin &
#telegram &
#uxterm &
#dwmstatus &
#wpa_gui &
#/opt/viber/Viber &
#mumble &

#exec /usr/local/bin/dwm > ~/.cache/dwm/stdout 2> ~/.cache/dwm/stderr
awesome
