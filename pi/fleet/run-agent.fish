#!/usr/bin/env fish
# The host Neovim owns the UI; only the Pi child enters sand's existing containment.
set -e NVIM
# Same as the interactive shell hook: load this project's .envrc, dropping env Neovim inherited from its launch dir.
direnv export fish | source
set -l fleet_dir (path dirname (status filename))
set -l sandbox_script (path resolve $fleet_dir/../../home/fish-functions/sand.fish)
source $sandbox_script -lc 'exec pi --extension "$HOME/.pi/agent/sandbox.ts" --extension "$HOME/.pi/agent/extensions/lib/fleet-session.ts" "$@"' -- -- $argv
