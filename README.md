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
sudo dd bs=4M status=progress conv=fsync oflag=direct if=$(ls nixos-*-linux.iso) of=/dev/sdX
```

### Building manually

```bash
nix build .#nixosConfigurations.iso.config.system.build.isoImage
```

### Fresh install

- With gparted (`sudo -E gparted`), create a GPT partition table with a 1G FAT32 partition labeled "BOOT" and the rest as another partition labeled "system".
- LUKS format the second partition with `cryptsetup luksFormat /dev/sdX2 --label cryptroot`.
- Open the LUKS partition with `cryptsetup open /dev/sdX2 cryptroot`.
- Format the LUKS partition with `mkfs.btrfs -L system /dev/mapper/cryptroot`.
- Create the subvolumes:

```bash
mount /dev/mapper/cryptroot /mnt
btrfs subvolume create /mnt/root
btrfs subvolume create /mnt/home
btrfs subvolume create /mnt/nix
```

- Mount the subvolumes:

```bash
mount -o subvol=root /dev/mapper/cryptroot /mnt
mkdir -p /mnt/home /mnt/nix /mnt/boot
mount -o subvol=home /dev/mapper/cryptroot /mnt/home
mount -o subvol=nix /dev/mapper/cryptroot /mnt/nix
mount /dev/disk/by-label/BOOT /mnt/boot
```

- Install nixos with `nixos-install --flake /iso/dotfiles#<hostname>`
- It will probably fail so:

```bash
nixos-enter
sbctl create-keys
exit
```

- Run nixos-install again

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
- GParted needs `sudo -E gparted` to run
- Although it shouldn't be needed, to change the M720 Triathlon buttons:

```bash
sudo nix shell nixpkgs#solaar --command solaar-cli config 1 persistent-remappable-keys "MultiPlatform Gesture Button" "F14"
```

- For script compatibility:

```bash
echo -e "#!/bin/sh\nexec /usr/bin/env bash \$@" | sudo tee /bin/bash
echo -e "#!/bin/sh\nexec /usr/bin/env bash \$@" | sudo tee /usr/bin/bash
echo -e "#!/bin/sh\nexec /usr/bin/env python \$@" | sudo tee /usr/bin/python
echo -e "#!/bin/sh\nexec /usr/bin/env python3 \$@" | sudo tee /usr/bin/python3
sudo chmod +x /bin/bash /usr/bin/bash /usr/bin/python /usr/bin/python3
```

- If a machine that uses opnix is set up, `/etc/opnix.env` needs to be populated with:

```bash
OP_SERVICE_ACCOUNT_TOKEN="{your token here}"
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

## Pre-commit hook linting

`.git/hooks/pre-commit`:

```bash
#!/bin/sh

# Navigate to the root of the Git repository
cd "$(git rev-parse --show-toplevel)" || exit 1

# Run statix check
statix check

# Check if statix check was successful
if [ $? -ne 0 ]; then
  echo "Statix check failed. Please fix the issues before committing."
  exit 1
fi
```
