{ pkgs, ... }: let
  # Partitions
  add_part = "/dev/disk/by-uuid/f4d0a081-deb5-45cb-b610-dfaf2af14cd3";
  root_part = "/dev/disk/by-uuid/faa05c46-36c9-4662-8b1c-fb81b44e23d8";
  # cryptvms_part = "/dev/disk/by-uuid/acf3064a-68a3-4b8a-897d-e1e717e56b12";

  # BTRFS filesystem (within LUKS)
  cryptroot_fs = "/dev/disk/by-uuid/59584c8e-45e7-4510-ae34-6c443260a5e1"; # The BTRFS is in RAID1 so the UUID is the same for both disks
in {
  imports = [
    ./components/amd.nix
    ./components/boot.nix
    ./components/peripherals.nix
    ./components/virtualbox.nix
  ];

  boot.initrd.luks.devices = {
    cryptadd.device = add_part;
    cryptroot.device = root_part;
  };

  fileSystems = {
    "/" = {
      device = cryptroot_fs;
      fsType = "btrfs";
      options = [ "subvol=nixroot" ];
    };
    "/home" = {
      device = cryptroot_fs;
      fsType = "btrfs";
      options = [ "subvol=home" ];
    };
    "/nix" = {
      device = cryptroot_fs;
      fsType = "btrfs";
      options = [ "subvol=nixroot/nix" ];
    };

    "/boot" = {
      device = "/dev/disk/by-label/BOOT"; # replace with your actual EFI partition UUID
      fsType = "vfat";
      options = [
        "uid=0"
        "gid=0"
        "umask=077"
        "fmask=077"
        "dmask=077"
      ];
    };

    "/home/dzervas/CryptVMs" = {
      device = "/dev/mapper/cryptvms";
      fsType = "ext4";
    };
  };

  environment.etc.crypttab.text = "cryptvms UUID=acf3064a-68a3-4b8a-897d-e1e717e56b12 /etc/cryptsetup_cryptvms luks,discard,nofail";
  swapDevices = [{ device = "/home/dzervas/CryptVMs/swapfile"; }];

  services.btrfs.autoScrub = {
    enable = true;
    interval = "weekly";
  };

  stylix.image = pkgs.fetchurl {
    # Photo by Wren Meinberg on Unsplash: https://unsplash.com/photos/forest-covered-with-fogs-Fs-bcmsV-hA
    url = "https://images.unsplash.com/photo-1524252500348-1bb07b83f3be";
    sha256 = "sha256-3gH1F4MAM2bKhfHWZrEvCasY8T+rQVxWnKBfHmtTOrM=";
  };
}
