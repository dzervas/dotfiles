{ pkgs, ... }: let
  cryptroot_disk = "/dev/disk/by-uuid/59584c8e-45e7-4510-ae34-6c443260a5e1"; # The BTRFS is in RAID1 so the UUID is the same for both disks
  add_disk = "/dev/disk/by-uuid/f4d0a081-deb5-45cb-b610-dfaf2af14cd3";
  root_disk = "/dev/disk/by-uuid/faa05c46-36c9-4662-8b1c-fb81b44e23d8";
in {
  imports = [
    ./components/amd.nix
    ./components/efi-luks.nix
    ./components/virtualbox.nix
  ];

  boot.initrd.luks.devices = {
    cryptadd.device = add_disk;
    cryptroot.device = root_disk;
	# cryptvms = {
		# device = "/dev/disk/by-uuid/acf3064a-68a3-4b8a-897d-e1e717e56b12";
		# keyFile = "/etc/"
	# };
  };

  fileSystems = {
    "/" = {
      device = cryptroot_disk;
      fsType = "btrfs";
      options = [ "subvol=nixroot" ];
    };
    "/home" = {
      device = cryptroot_disk;
      fsType = "btrfs";
      options = [ "subvol=home" ];
    };
    "/nix" = {
      device = cryptroot_disk;
      fsType = "btrfs";
      options = [ "subvol=nixroot/nix" ];
    };

    "/boot" = {
      device = "/dev/disk/by-label/BOOT"; # replace with your actual EFI partition UUID
      fsType = "vfat";
    };

    # "/home/dzervas/CryptVMs" = {
      # device = cryptroot_disk;
      # fsType = "btrfs";
      # options = [ "subvol=nixroot/nix" ];
    # };
  };

  # swapDevices = [{ device = "/home/dzervas/CryptVMs/swapfile"; }];

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
