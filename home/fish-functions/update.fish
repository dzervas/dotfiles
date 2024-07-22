set -f fish_trace 1
sudo nix-channel --update
nix flake update $FLAKE_URL
set -fe fish_trace

rebuild "Update $(date)"
