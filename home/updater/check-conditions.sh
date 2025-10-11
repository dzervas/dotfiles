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
WINDOW_INFO=$(hyprctl activewindow -j 2>/dev/null || echo '{"fullscreen": 0, "inhibitingIdle": false}')
FULLSCREEN=$(echo "$WINDOW_INFO" | jq -r '.fullscreen // 0')
INHIBITED=$(echo "$WINDOW_INFO" | jq -r '.inhibitingIdle // false')

# Log current state
echo "Idle: $IDLE, Fullscreen: $FULLSCREEN, Inhibited: $INHIBITED" >&2

# Low-impact conditions:
# 1. System is idle (IdleHint=yes)
# 2. Fullscreen window + idle inhibitor active (media playback)
if [[ "$IDLE" == "yes" ]]; then
    echo "System is idle" >&2
    exit 0
elif [[ "$FULLSCREEN" == "1" && "$INHIBITED" == "true" ]]; then
    echo "Fullscreen media detected" >&2
    exit 0
else
    echo "System is active" >&2
    exit 1
fi
