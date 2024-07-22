sudo nix-channel --update
nix flake update $FLAKE_URL
rebuild "Update $(date)"
sudo nix store gc
sudo nix store optimize
