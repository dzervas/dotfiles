{ pkgs, ... }: let
  # Partitions
  add_part = "/dev/disk/by-uuid/f4d0a081-deb5-45cb-b610-dfaf2af14cd3";
  root_part = "/dev/disk/by-uuid/faa05c46-36c9-4662-8b1c-fb81b44e23d8";

  # BTRFS filesystem (within LUKS)
  system_fs = "/dev/mapper/cryptroot"; # The BTRFS is in RAID1 so the UUID is the same for both disks
in {
  imports = [
    ./components/amd.nix
    ./components/boot.nix
    ./components/libvirt.nix
    ./components/peripherals.nix
    ./components/restic.nix
    ./components/secure-boot.nix
    ./components/virtualbox.nix
  ];

  boot.initrd.luks.devices = {
    cryptadd.device = add_part;
    cryptroot.device = root_part;
  };

  # TODO: Share config with the laptop, subvolumes need to match
  fileSystems = {
    "/" = {
      device = system_fs;
      fsType = "btrfs";
      options = [ "subvol=nixroot" ];
    };
    "/home" = {
      device = system_fs;
      fsType = "btrfs";
      options = [ "subvol=home" ];
    };
    "/nix" = {
      device = system_fs;
      fsType = "btrfs";
      options = [ "subvol=nixroot/nix" ];
    };

    "/home/dzervas/CryptVMs" = {
      device = "/dev/mapper/cryptvms";
      fsType = "ext4";
    };
  };

  environment.etc.crypttab.text = "cryptvms UUID=acf3064a-68a3-4b8a-897d-e1e717e56b12 /etc/cryptsetup_cryptvms luks,discard,nofail";
  swapDevices = [{ device = "/home/dzervas/CryptVMs/swapfile"; }];

  # BTRFS dedup daemon
  services.beesd.filesystems = {
    root = {
      spec = "LABEL=linux-add";
      # Recommended accoding to the docs: https://github.com/Zygo/bees/blob/master/docs/config.md
      hashTableSizeMB = 128;
      extraOptions = [ "--thread-count" "8" ];
    };
  };

  stylix.image = pkgs.fetchurl {
    # Photo by Wren Meinberg on Unsplash: https://unsplash.com/photos/forest-covered-with-fogs-Fs-bcmsV-hA
    url = "https://images.unsplash.com/photo-1524252500348-1bb07b83f3be";
    sha256 = "sha256-3gH1F4MAM2bKhfHWZrEvCasY8T+rQVxWnKBfHmtTOrM=";
  };
}
