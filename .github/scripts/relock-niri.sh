#!/usr/bin/env bash
# Recover a niri session that stays locked with no lock screen (e.g. a rebuild
# restarted noctalia while locked). Run from another TTY as the session user,
# then switch back to niri's VT and unlock. Pass --restart if noctalia is wedged.
set -euo pipefail

export XDG_RUNTIME_DIR="${XDG_RUNTIME_DIR:-/run/user/$(id -u)}"
export DBUS_SESSION_BUS_ADDRESS="${DBUS_SESSION_BUS_ADDRESS:-unix:path=$XDG_RUNTIME_DIR/bus}"

# A TTY shell has no session environment; take it from niri's socket name.
NIRI_SOCKET=$(compgen -G "$XDG_RUNTIME_DIR/niri.wayland-*.sock" | head -n1) || {
	echo "niri is not running" >&2
	exit 1
}
export NIRI_SOCKET
WAYLAND_DISPLAY=$(basename "$NIRI_SOCKET" | cut -d. -f2)
export WAYLAND_DISPLAY

if [[ ${1:-} == --restart ]]; then
	systemctl --user restart noctalia
else
	systemctl --user start noctalia
fi

# noctalia msg reports "not running" until the shell is up, so retry.
# niri replaces the dead lock with this one ("replacing existing dead lock").
for _ in $(seq 30); do
	noctalia msg session lock 2>/dev/null && exit 0
	sleep 0.5
done
noctalia msg session lock
