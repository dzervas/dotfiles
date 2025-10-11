#!/usr/bin/env bash
# Update flake inputs and build new NixOS generation
# Works directly in the dotfiles directory (no copying)

set -euo pipefail

DOTFILES_PATH="${DOTFILES_PATH:-$HOME/Lab/dotfiles}"
LOCK_BACKUP="/tmp/flake.lock.backup.$$"

echo "Starting flake update and build in $DOTFILES_PATH..." | systemd-cat -t flake-builder -p info

# Verify dotfiles directory exists
if [[ ! -d "$DOTFILES_PATH" ]]; then
    echo "ERROR: Dotfiles directory not found: $DOTFILES_PATH" | systemd-cat -t flake-builder -p err
    notify-send -u critical "System Update Failed" "Dotfiles directory not found: $DOTFILES_PATH"
    exit 1
fi

# Change to dotfiles directory
cd "$DOTFILES_PATH" || {
    echo "ERROR: Failed to cd to $DOTFILES_PATH" | systemd-cat -t flake-builder -p err
    notify-send -u critical "System Update Failed" "Cannot access dotfiles directory"
    exit 1
}

# Backup current flake.lock
if [[ -f "flake.lock" ]]; then
    cp flake.lock "$LOCK_BACKUP"
    echo "Backed up flake.lock to $LOCK_BACKUP" | systemd-cat -t flake-builder -p info
else
    echo "WARNING: No flake.lock found to backup" | systemd-cat -t flake-builder -p warning
fi

# Update flake inputs
echo "Updating flake inputs..." | systemd-cat -t flake-builder -p info
if bash "$DOTFILES_PATH/.github/scripts/flake-update.sh" 2>&1 | systemd-cat -t flake-builder -p info; then
    echo "Flake inputs updated successfully" | systemd-cat -t flake-builder -p info
else
    echo "Failed to update flake inputs" | systemd-cat -t flake-builder -p err

    # Restore backup on failure
    if [[ -f "$LOCK_BACKUP" ]]; then
        cp "$LOCK_BACKUP" flake.lock
        echo "Restored original flake.lock" | systemd-cat -t flake-builder -p info
    fi

    notify-send -u critical "System Update Failed" "Flake update failed - check journal"
    rm -f "$LOCK_BACKUP"
    exit 1
fi

# Build (but don't switch) the system configuration
HOSTNAME=$(hostname)
echo "Building system configuration for $HOSTNAME..." | systemd-cat -t flake-builder -p info

if nixos-rebuild build --flake ".#$HOSTNAME" --override-input nix-private "path:.private" 2>&1 | systemd-cat -t flake-builder -p info; then
    echo "Build successful!" | systemd-cat -t flake-builder -p info

    # Get generation number from result symlink
    if [[ -L "result" ]]; then
        GENERATION=$(readlink result | grep -oP 'system-\K[0-9]+-link' || echo "unknown")
    else
        GENERATION="unknown"
    fi

    # Success notification
    notify-send -u normal "System Update Ready" "Generation $GENERATION built successfully and ready to switch"

    # Clean up backup (we're keeping the new flake.lock)
    rm -f "$LOCK_BACKUP"
    echo "Updated flake.lock in $DOTFILES_PATH" | systemd-cat -t flake-builder -p info

    exit 0
else
    echo "Build failed - restoring original flake.lock" | systemd-cat -t flake-builder -p err

    # Restore backup on failure
    if [[ -f "$LOCK_BACKUP" ]]; then
        cp "$LOCK_BACKUP" flake.lock
        echo "Restored original flake.lock" | systemd-cat -t flake-builder -p info
    fi

    notify-send -u critical "System Update Failed" "Build failed - check journal with: journalctl --user -u flake-builder"
    rm -f "$LOCK_BACKUP"
    exit 1
fi
