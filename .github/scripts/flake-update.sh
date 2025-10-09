#!/usr/bin/env bash
command grep --no-filename -r '# nix-update:' overlays/ | \
	cut -d':' -f2 | \
	xargs -L1 nix-update -f overlays/update-shim.nix

NIXPKGS_URL="github:NixOS/nixpkgs/$(curl -sL "https://prometheus.nixos.org/api/v1/query?query=channel_revision" | jq -r '.data.result[] | select(.metric.channel=="nixpkgs-unstable") | .metric.revision')"
nix flake update --accept-flake-config --flake . --override-input nixpkgs "$NIXPKGS_URL"
