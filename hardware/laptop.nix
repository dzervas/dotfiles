{ inputs, pkgs, ... }: let
  cryptroot_part = "/dev/disk/by-label/cryptroot";
  system_fs = "/dev/disk/by-label/system";
in {
  imports = [
    ./components/amd.nix
    ./components/boot.nix
    ./components/peripherals.nix
    ./components/secure-boot.nix
    # ./components/virtualbox.nix
    ./components/libvirt.nix
    ./components/laptop.nix
    inputs.nixos-hardware.nixosModules.framework-13-7040-amd
  ];

  boot.initrd.luks.devices.cryptroot.device = cryptroot_part;

  fileSystems = {
    "/" = {
      device = system_fs;
      fsType = "btrfs";
      options = [ "subvol=root" ];
    };
    "/home" = {
      device = system_fs;
      fsType = "btrfs";
      options = [ "subvol=home" ];
    };
    "/nix" = {
      device = system_fs;
      fsType = "btrfs";
      options = [ "subvol=nix" ];
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
  };

  swapDevices = [{ device = "/swap/swapfile"; }];

  services.btrfs.autoScrub = {
    enable = true;
    interval = "weekly";
  };

  stylix.image = pkgs.fetchurl {
    # Photo by Dave Hoefler on Unsplash: https://unsplash.com/photos/sunlight-through-trees-hQNY2WP-qY4
    url = "https://unsplash.com/photos/hQNY2WP-qY4/download?ixid=M3wxMjA3fDB8MXxhbGx8fHx8fHx8fHwxNzIwMzUyNTA4fA&force=true";
    sha256 = "sha256-gw+BkfVkuzMEI8ktiLoHiBMupiUS9AoiB+acFTCt36g=";
  };

  environment.systemPackages = with pkgs; [
    powertop
  ];

  # powerManagement = {
  #   enable = true;
  #   powertop.enable = true;
  # };
  services.power-profiles-daemon.enable = true;
}
