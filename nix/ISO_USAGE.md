# NixOS ISO Usage

This is my personal configuration as a NixOS iso.

## Building locally

```bash
nix build ./nix#iso
```

## Downloading

In NixOS:

```bash
# Once per system
nix shell nixpkgs#oras nixpkgs#gh -c "gh auth token | oras login ghcr.io --password-stdin -u github"

nix shell nixpkgs#oras -c oras pull ghcr.io/dzervas/dotfiles/nixos-iso:latest
```

In other systems, install oras and github cli:

```bash
# Once per system
gh auth token | oras login ghcr.io --password-stdin -u github

oras pull ghcr.io/dzervas/dotfiles/nixos-iso:latest
```

## Writing to USB

```bash
# Find the USB device
lsblk
# Replace /dev/sdX with the USB device
sudo dd bs=4M status=progress oflag=sync if=$(ls nixos-*-linux.iso) of=/dev/sdX
```
