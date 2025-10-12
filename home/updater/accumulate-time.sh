#!/usr/bin/env bash
# Accumulate idle/media time and trigger builder when threshold reached

set -euo pipefail

STATE_DIR="${STATE_DIR:-$XDG_RUNTIME_DIR/flake-updater}"
STATE_FILE="$STATE_DIR/accumulated-minutes"
THRESHOLD="${IDLE_THRESHOLD:-15}"

# Ensure state directory exists
mkdir -p "$STATE_DIR"

# Initialize state file if missing or invalid
if [[ ! -f "$STATE_FILE" ]] || ! [[ $(cat "$STATE_FILE" 2>/dev/null || echo "x") =~ ^[0-9]+$ ]]; then
    echo "0" > "$STATE_FILE"
fi

# Read current accumulated time
ACCUMULATED=$(cat "$STATE_FILE")

# Check conditions
if bash "$(dirname "$0")/check-conditions.sh"; then
    # Low-impact state: increment counter
    ACCUMULATED=$((ACCUMULATED + 1))
    echo "$ACCUMULATED" > "$STATE_FILE"
    echo "Accumulated: $ACCUMULATED/$THRESHOLD minutes" | systemd-cat -t flake-accumulator -p info

    # Check if threshold reached
    if [[ $ACCUMULATED -ge $THRESHOLD ]]; then
        echo "Threshold reached! Triggering builder..." | systemd-cat -t flake-accumulator -p info
        echo "0" > "$STATE_FILE"  # Reset counter

        # Check if builder is already running
        if systemctl --user is-active --quiet flake-builder.service; then
            echo "Builder already running, skipping" | systemd-cat -t flake-accumulator -p warning
        else
            systemctl --user start flake-builder.service
        fi
    fi
else
    # Active state: reset counter
    if [[ $ACCUMULATED -gt 0 ]]; then
        echo "Activity detected, resetting counter (was $ACCUMULATED)" | systemd-cat -t flake-accumulator -p info
        echo "0" > "$STATE_FILE"
    fi
fi
