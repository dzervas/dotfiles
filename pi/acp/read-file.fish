#!/usr/bin/env fish
# Diff snapshots must read through the same project sandbox as Pi, not the host.
set -l acp_dir (path dirname (status filename))
source $acp_dir/../../home/fish-functions/sand.fish \
	--ro-bind "$acp_dir/read-file.mjs:/tmp/pi-acp-read-file.mjs" \
	-c 'exec node /tmp/pi-acp-read-file.mjs "$@"' -- -- $argv
