#!/usr/bin/env bash
cryptsetup open /dev/disk/by-label/cryptroot cryptroot
mount -o subvol=root /dev/mapper/cryptroot /mnt
mkdir -p /mnt/home /mnt/nix /mnt/boot
mount -o subvol=home /dev/mapper/cryptroot /mnt/home
mount -o subvol=nix /dev/mapper/cryptroot /mnt/nix
mount /dev/disk/by-label/BOOT /mnt/boot
exec nixos-enter
