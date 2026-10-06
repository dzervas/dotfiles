#!/usr/bin/env fish
# The adapter stays on the host; every Pi session enters sand in its own cwd.
set -l acp_dir (path dirname (status filename))
set -gx PI_ACP_PI_COMMAND (path resolve $acp_dir/run-pi.fish)
set -gx PI_ACP_READ_COMMAND (path resolve $acp_dir/read-file.fish)
exec pi-acp $argv
