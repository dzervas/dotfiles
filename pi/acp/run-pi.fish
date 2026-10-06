#!/usr/bin/env fish
# pi-acp supplies the session's project cwd when spawning this executable.
# Reload direnv here so a host adapter cannot leak its launch project's environment.
direnv export fish | source
set -gx PI_ACP_FORMS 1
set -l acp_dir (path dirname (status filename))
source $acp_dir/../../home/fish-functions/sand.fish -lc 'exec pi --extension "$HOME/.pi/agent/sandbox.ts" "$@"' -- -- $argv
