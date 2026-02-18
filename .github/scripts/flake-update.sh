#!/usr/bin/env bash
command grep --no-filename -r '# nix-update:' overlays/ | \
	cut -d':' -f2 | \
	xargs -L1 nix-update -f overlays/update-shim.nix

rg flake-update: flake.nix | \
sed -E 's#.*"github:(.+/.+)/(.+)".*flake-update:(.*)$#\1 \2 \3#' | \
while read -r repo old regex; do
	new=$(curl -s "https://api.github.com/repos/$repo/tags" | jq -r --arg re "$regex" '[ .[].name | select(test($re)) ] | first')
	sd "$repo/$old" "$repo/$new" flake.nix
done

# NIXPKGS_URL="github:NixOS/nixpkgs/$(curl -sL "https://prometheus.nixos.org/api/v1/query?query=channel_revision" | jq -r '.data.result[] | select(.metric.channel=="nixpkgs-unstable") | .metric.revision')"
NIXPKGS_URL="github:NixOS/nixpkgs/$(curl -sL -H "Accept: application/json" "https://hydra.nixos.org/jobset/nixos/trunk-combined/latest-eval" | jq -r '.jobsetevalinputs.nixpkgs.revision')"
nix flake update --accept-flake-config --flake . --override-input nixpkgs "$NIXPKGS_URL"
