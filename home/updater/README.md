# Auto-Updater

Automatically updates and builds NixOS configurations in the background when the system is idle or displaying fullscreen media.

## How It Works

- **Timer**: Runs every minute checking system state (idle via `loginctl`, fullscreen+inhibitor via `hyprctl`)
- **Accumulator**: Counts idle/media minutes; triggers build at 15-minute threshold
- **Builder**: Runs `nix flake update` + `nixos-rebuild build`, copies `flake.lock` on success
- **Activity Monitor**: Renices builder to priority 19 when user becomes active

## Monitoring

```bash
journalctl --user -u flake-accumulator -f    # Watch accumulator
journalctl --user -u flake-builder -f        # Watch builds
cat /run/user/$UID/flake-updater/accumulated-minutes  # Check counter
```
