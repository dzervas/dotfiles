# NixOS Configuration

## Rebuilding

```bash
sudo nixos-rebuild switch --flake .#<hostname>
```

## Updating

```bash
sudo nix-channel --update
nix flake update
sudo nixos-rebuild switch --flake .
sudo nix store gc
sudo nix store optimize
```

## Live CD

There's also a live CD configuration in `hardware/iso`.

### Download

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

### Writing to USB

```bash
# Find the USB device
lsblk
# Replace /dev/sdX with the USB device
sudo dd bs=4M status=progress oflag=sync if=$(ls nixos-*-linux.iso) of=/dev/sdX
```

### Building manually

```bash
nix build .#iso
```

## Troubleshooting

To repair the store:

```bash
nix-store --verify --check-contents --repair
```

if a file is empty due to corruption and can't be fixed:

```bash
nix-store --query --referrers-closure $(find /store -maxdepth 1 -type f -name '*.drv' -size 0) | xargs nix-store --delete --ignore-liveness
nix-store --gc
nix-store --verify --check-contents --repair
```

A `.nix` file was empty and I had to `sudo nix-store --query --roots <path>`
to find the softlink under the home, remove it and re-run the initial home-manager
rebuild.

### To update to a specific nixpkgs commit

```bash
nix flake update --override-input nixpkgs github:NixOS/nixpkgs/7252b96d60dc2ccf3971e436811cfce42b258669
```

## Quirks

- VSCode needs `"password-store": "gnome-libsecret"` to `~/.vscode/argv.json` to see gnome-keyring
- GParted needs `nix-shell -p xorg.xhost --run xhost si:localuser:root` to run
- Although it shouldn't be needed, to change the M720 Triathlon buttons:

```bash
sudo nix shell nixpkgs#solaar --command solaar-cli config 1 persistent-remappable-keys "MultiPlatform Gesture Button" "F14"
```

### Secure boot

```fish
# Crete the keys
sudo sbctl create-keys
# Check that everything is signed (apart from the kernel under nixos dir)
sudo sbctl verify
# Enter setup mode from the BIOS
sudo sbctl enroll-keys --microsoft
# Check that secure boot is enabled
sudo sbctl status
```
