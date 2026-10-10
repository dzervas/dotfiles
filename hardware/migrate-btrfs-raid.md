# Desktop: replace the 1TB NVMe with a 4TB NVMe

The old 1TB and new 4TB cannot be connected together. Recover its Btrfs member
from the surviving 2TB drive, then move CryptVMs onto the 4TB and grow Btrfs.

| Drive | Final layout |
| --- | --- |
| Existing 2TB | Existing ESP + remaining space as LUKS/Btrfs RAID1 member |
| New 4TB | 1GiB ESP + roughly 2TB LUKS/Btrfs member + remainder as LUKS/ext4 CryptVMs |

Result: roughly **2TB usable mirrored Btrfs + 2TB unmirrored CryptVMs**, less
overhead. The 2TB drive stays, but its partition layout changes.

This guide is included on the ISO at `/iso/migrate-btrfs-raid.md`.
Commands below use **Bash**. Run ISO commands from a root shell, one section at
a time. Check every result; stop on errors. This is not a script to paste whole.
Never repeat formatting commands after an interruption.

## 1. Before shutting down the installed system

```bash
lsblk -b -o NAME,SIZE,MODEL,SERIAL,FSTYPE,LABEL,UUID,PARTUUID,MOUNTPOINTS > ~/disks.txt
sudo btrfs filesystem show /
sudo btrfs filesystem usage /
sudo btrfs scrub start -B /
sudo cp -a /boot ~/boot-backup
sudo test -f /boot/EFI/BOOT/BOOTX64.EFI
```

- Record the **cryptroot devid**, disk serials, UUIDs and partition boundaries
  externally. Save the 2TB partition table with `sudo sfdisk --dump /dev/disk/by-id/…`.
- Confirm **Data, Metadata and System are RAID1**, not `single` or `DUP`.
  Require a scrub with no uncorrectable errors before removing either member.
  (check that filesystem usage reports {Data,Metadata,System},RAID1)
- Independently back up important data, **including CryptVMs**: the configured
  restic job does not cover it. Keep an external ESP backup too.
- Keep the cryptvms keyfile available securely in the ISO. Do not print its contents.
- This machine uses **Lanzaboote/Secure Boot**. Test that the rescue ISO boots,
  and know how to select an EFI file or recreate a firmware boot entry.
- Identify the existing 2TB ESP. If it is labelled `BOOT`, relabel it after
  confirming its purpose; the new ESP must be the only partition with that label.
  Do not wipe an unidentified ESP.

Shut down cleanly, replace the 1TB with the 4TB, and boot the ISO in UEFI mode.

## 2. Identify disks and plan partitions

Use persistent whole-disk paths, **not assumed NVMe numbering**. Replace the
placeholders below with the observed values. Keep these assignments for later
sections (and record them externally if rebooting).

```bash
lsblk -b -o NAME,SIZE,MODEL,SERIAL,FSTYPE,LABEL,UUID,PARTUUID,MOUNTPOINTS
findmnt
swapon --show

keep=/dev/disk/by-id/REPLACE_WITH_RETAINED_2TB
new=/dev/disk/by-id/REPLACE_WITH_NEW_4TB
root_devid=REPLACE_WITH_RECORDED_MISSING_DEVID
keyfile=/REPLACE_WITH_SECURE_KEYFILE_PATH

keep_root=${keep}-part2
keep_vms=${keep}-part3
new_esp=${new}-part1
new_root=${new}-part2
new_vms=${new}-part3

cryptsetup luksUUID "$keep_root"   # expect f4d0a081-deb5-45cb-b610-dfaf2af14cd3
cryptsetup luksUUID "$keep_vms"    # expect acf3064a-68a3-4b8a-897d-e1e717e56b12
parted "$keep" unit s print free
```

Both disks must be unmounted, with no open mappings or active swap. `/mnt` must
be unused. Confirm the retained disk has the expected p2 Btrfs and p3 CryptVMs.

Size the new Btrfs partition slightly larger than the **entire retained disk**.
This avoids rounding a nominal “2TB” too small and allows margin for LUKS offsets.
The extra space beyond the matching RAID1 member will not provide mirrored capacity.

```bash
keep_bytes=$(blockdev --getsize64 "$keep")
root_end_mib=$((1025 + (keep_bytes + 1048575) / 1048576 + 64))
keep_start=$(parted -ms "$keep" unit s print | awk -F: '$1 == 2 {print $2}')
printf 'Retained p2 start: %s; new p2 end: %s MiB\n' "$keep_start" "$root_end_mib"
```

Record `keep_start` externally. It must never change.

**The next commands destroy the new disk's partition table. Check its serial again.**

```bash
parted -s -a optimal "$new" mklabel gpt \
  mkpart ESP fat32 1MiB 1025MiB set 1 esp on \
  mkpart cryptroot 1025MiB "${root_end_mib}MiB" \
  mkpart cryptvms "${root_end_mib}MiB" 100%
partprobe "$new"
udevadm settle
parted "$new" unit MiB print
mkfs.vfat -F 32 -n BOOT "$new_esp"
```

## 3. Restore Btrfs redundancy

Reusing the old LUKS UUID keeps `root_part` in `hardware/desktop.nix` valid.
It does **not** copy encryption keys or token enrollments. Choose a passphrase
that you can enter at boot. Do not create a new Btrfs filesystem on this device.

```bash
cryptsetup luksFormat --type luks2 \
  --uuid faa05c46-36c9-4662-8b1c-fb81b44e23d8 "$new_root"
cryptsetup open "$new_root" cryptroot
cryptsetup open "$keep_root" cryptadd
mkdir -p /run/migrate-btrfs
mount -o degraded,subvolid=5 /dev/mapper/cryptadd /run/migrate-btrfs
btrfs filesystem show /run/migrate-btrfs
btrfs filesystem usage /run/migrate-btrfs
```

Confirm the missing device is `$root_devid` and all allocation profiles are RAID1.
Then replace it; `-B` waits for completion. Prevent suspend during the operation.

```bash
btrfs replace start -B "$root_devid" /dev/mapper/cryptroot /run/migrate-btrfs
btrfs replace status /run/migrate-btrfs
btrfs filesystem show /run/migrate-btrfs
btrfs scrub start -B /run/migrate-btrfs
```

Require successful replacement, both devices present, and a clean scrub.

## 4. Mount the installed system and restore the ESP

```bash
mount -o subvol=nixroot /dev/mapper/cryptroot /mnt
mount -o subvol=home /dev/mapper/cryptroot /mnt/home
mount -o subvol=nixroot/nix /dev/mapper/cryptroot /mnt/nix
mount "$new_esp" /mnt/boot
cp -r /mnt/home/dzervas/boot-backup/. /mnt/boot/
diff -qr /mnt/home/dzervas/boot-backup /mnt/boot
sync
```

Require no content differences. FAT cannot preserve Unix ownership/permissions,
so use a content copy rather than `cp -a`. Confirm
`/mnt/boot/EFI/BOOT/BOOTX64.EFI` exists. Firmware fallback is not guaranteed;
prepare an explicit new boot entry or firmware boot-from-file route.

## 5. Move CryptVMs while still in the ISO

The source must have shut down cleanly. Keep it read-only; `noload` prevents
journal replay. If the read-only filesystem check reports errors, stop and
resolve them before copying.

```bash
mkdir -p /run/migrate-vms-old
cryptsetup open --readonly --key-file "$keyfile" "$keep_vms" cryptvms-old
e2fsck -fn /dev/mapper/cryptvms-old
mount -o ro,noload /dev/mapper/cryptvms-old /run/migrate-vms-old

cryptsetup luksFormat --type luks2 --key-file "$keyfile" "$new_vms"
cryptsetup open --key-file "$keyfile" "$new_vms" cryptvms
mkfs.ext4 /dev/mapper/cryptvms
mount /dev/mapper/cryptvms /mnt/home/dzervas/CryptVMs
rsync -aHAXS --numeric-ids --info=progress2 --exclude=/swapfile \
  /run/migrate-vms-old/ /mnt/home/dzervas/CryptVMs/

# Checksum-based dry run: require success and no reported differences.
rsync -aHAXScni --numeric-ids --exclude=/swapfile \
  /run/migrate-vms-old/ /mnt/home/dzervas/CryptVMs/
```

Recreate swap rather than copying it with `rsync -S`, which could create holes.
Check that the recorded size is positive and a multiple of 1MiB before using it.

```bash
swap_bytes=$(stat -c %s /run/migrate-vms-old/swapfile)
printf 'Swap bytes: %s\n' "$swap_bytes"
dd if=/dev/zero of=/mnt/home/dzervas/CryptVMs/swapfile bs=1M \
  count="$((swap_bytes / 1048576))" status=progress
chmod 600 /mnt/home/dzervas/CryptVMs/swapfile
mkswap /mnt/home/dzervas/CryptVMs/swapfile
swapon /mnt/home/dzervas/CryptVMs/swapfile
swapon --show
swapoff /mnt/home/dzervas/CryptVMs/swapfile
sync
```

## 6. Update configuration and prepare boot

```bash
cryptsetup luksUUID "$new_vms"
```

In `/mnt/home/dzervas/Lab/dotfiles/hardware/desktop.nix`, replace only the
crypttab UUID `acf3064a-68a3-4b8a-897d-e1e717e56b12` with that new LUKS UUID.
Leave `root_part` and `add_part` unchanged.

```bash
nixos-enter --root /mnt
# Inside the installed system:
cd /home/dzervas/Lab/dotfiles
nixos-rebuild boot --flake .#desktop --install-bootloader
exit
```

Resolve private-input authentication and Secure Boot signing errors before
proceeding. Ensure the firmware entry targets the **new ESP**; otherwise arrange
to boot its `EFI/BOOT/BOOTX64.EFI` explicitly.

## 7. Unmount; optionally test boot before deleting the old copy

```bash
umount /run/migrate-vms-old
cryptsetup close cryptvms-old
umount /mnt/home/dzervas/CryptVMs
cryptsetup close cryptvms
umount /mnt/boot
umount /mnt/nix
umount /mnt/home
umount /mnt
umount /run/migrate-btrfs
cryptsetup close cryptroot
cryptsetup close cryptadd
```

**Recommended checkpoint:** boot the installed system now and verify that
`findmnt /home/dzervas/CryptVMs`, `lsblk`, and `swapon --show` identify the new
4TB-backed CryptVMs and active swap. Then return to the ISO and restore the Bash
variables from section 2, including the recorded `keep_start` and `root_devid`.
Do not repeat partitioning, formatting, or replacement.

You can instead remain in the ISO, but then deletion relies on the offline
verification without having tested the new boot configuration.

## 8. Delete old CryptVMs and grow the retained Btrfs member

**Point of no return for the old CryptVMs copy.** Require an independent backup,
a verified new copy, and prepared boot configuration. Neither drive should have
mounted filesystems, active swap or open encryption mappings.

```bash
lsblk -o NAME,SIZE,TYPE,FSTYPE,MOUNTPOINTS "$keep" "$new"
swapon --show
cryptsetup luksUUID "$keep_vms"    # still the OLD CryptVMs UUID
parted "$keep" unit s print free

parted -s "$keep" rm 3
parted -s "$keep" resizepart 2 100%
partprobe "$keep"
udevadm settle
parted "$keep" unit s print
cryptsetup resize "$keep_root"
```

Confirm p2's start still equals the recorded `keep_start`. Fresh LUKS mappings
will see the enlarged partition, so no live `cryptsetup resize` is needed.

```bash
cryptsetup open "$keep_root" cryptadd
cryptsetup open "$new_root" cryptroot
blockdev --getsize64 /dev/mapper/cryptadd
blockdev --getsize64 /dev/mapper/cryptroot
mkdir -p /run/migrate-btrfs
mount -o subvolid=5 /dev/mapper/cryptroot /run/migrate-btrfs
btrfs filesystem show /run/migrate-btrfs
```

The new cryptroot mapper should be at least as large as cryptadd. Read the
cryptadd devid from the output; verify cryptroot still has the recorded devid.

```bash
add_devid=REPLACE_WITH_DISPLAYED_CRYPTADD_DEVID
btrfs filesystem resize "${add_devid}:max" /run/migrate-btrfs
btrfs filesystem resize "${root_devid}:max" /run/migrate-btrfs
btrfs filesystem usage /run/migrate-btrfs
btrfs scrub start -B /run/migrate-btrfs
sync
umount /run/migrate-btrfs
cryptsetup close cryptroot
cryptsetup close cryptadd
```

Require a clean scrub, then reboot and verify mounts and swap again. No balance
is required just to make the expanded free space available.

Keep the old 1TB **disconnected**: it now has duplicate LUKS/Btrfs identities,
and is not an up-to-date rollback of the modified array.
