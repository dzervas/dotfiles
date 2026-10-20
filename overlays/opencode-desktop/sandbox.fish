#!@fish@/bin/fish --no-config
# Use the installed sand function; all filesystem mounts stay in sand.fish.
test (count $argv) -eq 1; or exit 1
set -l project (@coreutils@/bin/realpath -e -- $argv[1]); or exit 1
test -d "$project"; and test "$project" != /; and test "$project" != "$HOME"; or exit 1
set -l config "$HOME/.config"
set -q XDG_CONFIG_HOME; and test -n "$XDG_CONFIG_HOME"; and set config "$XDG_CONFIG_HOME"
set -p fish_function_path "$config/fish/functions"
functions -q sand; or exit 1
set -lx OPENCODE_CONFIG "@sandboxConfig@"
set -lx OPENCODE_MEMORY_PROJECT_NAMESPACE (@node@/bin/node --no-warnings --experimental-transform-types @namespace@ "$project" @git@/bin/git); or exit 1
set -e OPENCODE_SERVER_PASSWORD
cd -- "$project"; or exit 1
sand -c 'export XDG_CONFIG_HOME="$HOME/.config" XDG_DATA_HOME="$HOME/.local/share" XDG_STATE_HOME="$HOME/.local/state" XDG_CACHE_HOME="$HOME/.cache"; exec "$@"' \
    -- -- opencode serve --hostname 127.0.0.1 --port 0
