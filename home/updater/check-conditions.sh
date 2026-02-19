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

# Check for fullscreen window based on available compositor tooling
if command -v hyprctl >/dev/null 2>&1; then
    # Keep existing Hyprland behavior
    FULLSCREEN=$(hyprctl clients -j 2>/dev/null | jq 'reduce (.[] | select(.fullscreen > 0)) as $obj ({}; . * $obj) | .fullscreen // 0')
elif command -v niri >/dev/null 2>&1; then
    # Niri windows are exposed via `niri msg -j windows`
    FULLSCREEN=$(niri msg -j windows 2>/dev/null | jq 'if any(.[]?; (.is_fullscreen? == true) or (.fullscreen? == true) or ((.fullscreen? // 0) > 0)) then 1 else 0 end')
else
    exit 1
fi

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
