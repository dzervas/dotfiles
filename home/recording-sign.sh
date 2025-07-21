#!/usr/bin/env bash
set -euo pipefail

DEBOUNCE_TIME=0.1
OPEN_URL="http://exit-sign.lan/light/panel/turn_on"
CLOSE_URL="http://exit-sign.lan/light/panel/turn_off"

# TODO: check the camera and sign on boot

# Variables for debouncing
last_open_time=0

# Function to execute OPEN command with debouncing
handle_open() {
    echo "Executing OPEN command..."
    curl -s "$OPEN_URL" || echo "Failed to execute OPEN command"
    echo "OPEN command executed at $(date)"
}

# Function to execute CLOSE command
handle_close() {
    echo "Executing CLOSE command..."
    curl -s "$CLOSE_URL" || echo "Failed to execute CLOSE command"
    echo "CLOSE command executed at $(date)"
}

check_status() {
    # Sync the status on (re)start
    status=$(lsof -Q /dev/video* | wc -l)
    if [ "$status" -gt 0 ]; then
        echo "Camera is already open, sending OPEN command"
        handle_open
    else
        echo "Camera is already closed, sending CLOSE command"
        handle_close
    fi
}

echo "Script started. Waiting for OPEN or CLOSE commands..."
echo "Press Ctrl+C to exit."

# Main loop
inotifywait -m /dev -e open,close --include "video[0-9]+" --format "%e" | while read -r line; do
    current_time=$(date +%s)
    time_diff=$((current_time - last_open_time))

    if [ $time_diff -lt $DEBOUNCE_TIME ]; then
        { sleep $DEBOUNCE_TIME; check_status; } &
        continue
    fi
    last_open_time=$current_time

    # Trim whitespace and convert to uppercase
    command=$(echo "$line" | cut -d, -f2 | tr '[:lower:]' '[:upper:]' | xargs)

    case "$command" in
        "OPEN")
            handle_open
            ;;
        "CLOSE")
            handle_close
            ;;
        "")
            # Ignore empty lines
            ;;
        *)
            echo "Unknown command: $line. Expected OPEN or CLOSE."
            ;;
    esac
done
