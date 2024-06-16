{ config, pkgs, ... }:

{
  boot = {
    loader = {
      systemd-boot.enable = true;
      efi = {
        canTouchEfiVariables = true;
      };
    };

    initrd = {
      luks.devices = {
        root = {
          device = "/dev/disk/by-uuid/YOUR-UUID-HERE"; # replace with your actual UUID
          preLVM = true;
        };
      };
    };
  };

  fileSystems = {
    "/" = {
      device = "root";
      fsType = "btrfs";
      options = "subvol=/@";
    };
    "/home" = {
      device = "root";
      fsType = "btrfs";
      options = "subvol=/@home";
    };
    "/documents" = {
      device = "root";
      fsType = "btrfs";
      options = "subvol=/@documents";
    };
  };

  fileSystems."/boot" = {
    device = "/dev/disk/by-uuid/YOUR-EFI-UUID-HERE"; # replace with your actual EFI partition UUID
    fsType = "vfat";
  };
}
