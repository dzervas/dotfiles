{ pkgs, ... }: {
  boot = {
    consoleLogLevel = 0;
    kernelParams = [ "quiet" "udev.log_level=3" ];

    initrd = {
      availableKernelModules = [ "nvme" "xhci_pci" "ahci" "usb_storage" "sd_mod" ];
      verbose = false;
      systemd.enable = true;
    };

    loader = {
      efi.canTouchEfiVariables = true;
      systemd-boot.configurationLimit = 5;
    };

    plymouth.enable = true;
  };

  fileSystems = {
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

    "/home/dzervas/Downloads/tmp" = {
      fsType = "tmpfs";
      options = [
        "uid=1000"
        "gid=100" # Users GID
        "mode=0700"
        "size=5%"
        "user"
      ];
    };
  };

  services.btrfs.autoScrub = {
    enable = true;
    interval = "weekly";
  };

  environment.systemPackages = with pkgs; [ sbctl ];
}
