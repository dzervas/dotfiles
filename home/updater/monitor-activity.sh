#!/usr/bin/env bash
# Monitor user activity and adjust builder process priority

set -euo pipefail

NICE_LEVEL="${NICE_LEVEL:-19}"
STATE_DIR="${STATE_DIR:-/run/user/$UID/flake-updater}"
NICE_STATE_FILE="$STATE_DIR/is-niced"

# Ensure state directory exists
mkdir -p "$STATE_DIR"

# Find builder process PID
BUILDER_PID=$(systemctl --user show flake-builder.service -p MainPID --value 2>/dev/null || echo "0")

if [[ "$BUILDER_PID" == "0" ]] || ! kill -0 "$BUILDER_PID" 2>/dev/null; then
    echo "Builder not running, stopping monitor" | systemd-cat -t flake-activity-monitor -p info
    # Stop this timer since builder is done
    systemctl --user stop flake-activity-monitor.timer
    rm -f "$NICE_STATE_FILE"
    exit 0
fi

# Check if currently niced
IS_NICED=false
if [[ -f "$NICE_STATE_FILE" ]]; then
    IS_NICED=true
fi

# Check conditions
if bash "$(dirname "$0")/check-conditions.sh"; then
    # Low-impact state: restore normal priority if niced
    if $IS_NICED; then
        echo "Restoring normal priority for PID $BUILDER_PID" | systemd-cat -t flake-activity-monitor -p info
        renice -n 0 -p "$BUILDER_PID" || true
        rm -f "$NICE_STATE_FILE"
    fi
else
    # Active state: lower priority if not already niced
    if ! $IS_NICED; then
        echo "Lowering priority to $NICE_LEVEL for PID $BUILDER_PID" | systemd-cat -t flake-activity-monitor -p info
        renice -n "$NICE_LEVEL" -p "$BUILDER_PID" || true
        touch "$NICE_STATE_FILE"
    fi
fi
