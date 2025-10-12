#!/usr/bin/env bash
# Exit 0 if system is in "low-impact" state (idle OR fullscreen media)
# Exit 1 if system is active

set -euo pipefail

# Get session ID
SESSION=$(loginctl show-user "$USER" -p Display --value 2>/dev/null || echo "")
if [[ -z "$SESSION" ]]; then
    echo "No active session found, treating as active" >&2
    exit 1
fi

# Check if idle (via loginctl IdleHint)
IDLE=$(loginctl show-session "$SESSION" -p IdleHint --value 2>/dev/null || echo "no")

# Check for fullscreen window and idle inhibitor (hyprctl returns 0/1 and true/false)
FULLSCREEN=$(hyprctl clients -j 2>/dev/null | jq 'reduce (.[] | select(.fullscreen > 0)) as $obj ({}; . * $obj) | .fullscreen // 0')

# Low-impact conditions:
# 1. System is idle (IdleHint=yes)
# 2. Fullscreen window (media playback)
if [[ "$IDLE" == "yes" ]]; then
    exit 0
elif [[ "$FULLSCREEN" -gt "0" ]]; then
    exit 0
else
    exit 1
fi
