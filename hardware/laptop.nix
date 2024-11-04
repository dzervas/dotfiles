{ pkgs, ... }: let
  root_part = "/dev/disk/by-uuid/3153b379-9bc8-48e0-baa8-5e9ba59db081";
  cryptroot_fs = "/dev/disk/by-uuid/554c3697-ff49-4f1c-af96-69624a12910b";
in {
  imports = [
    ./components/amd.nix
    ./components/boot.nix
    ./components/peripherals.nix
    ./components/secure-boot.nix
    ./components/virtualbox.nix
    ./components/laptop.nix
  ];

  boot.initrd.luks.devices.cryptroot.device = root_part;

  # Generated using nix-shell -p lm_sensors --run pwmconfig
  hardware.fancontrol.config = ''
    INTERVAL=10
    DEVPATH=hwmon7=devices/platform/dell_smm_hwmon
    DEVNAME=hwmon7=dell_smm
    FCTEMPS=hwmon7/pwm1=hwmon7/temp1_input
    FCFANS= hwmon7/pwm1=hwmon7/fan1_input
    MINTEMP=hwmon7/pwm1=45
    MAXTEMP=hwmon7/pwm1=80
    MINSTART=hwmon7/pwm1=150
    MINSTOP=hwmon7/pwm1=0
    MAXPWM=hwmon7/pwm1=200
  '';

  fileSystems = {
    "/" = {
      device = cryptroot_fs;
      fsType = "btrfs";
      options = [ "subvol=root" ];
    };
    "/home" = {
      device = cryptroot_fs;
      fsType = "btrfs";
      options = [ "subvol=home" ];
    };
    "/nix" = {
      device = cryptroot_fs;
      fsType = "btrfs";
      options = [ "subvol=nix" ];
    };

    "/boot" = {
      device = "/dev/disk/by-label/BOOT"; # replace with your actual EFI partition UUID
      fsType = "vfat";
      options = [ "umask=077" ];
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
    teleport
  ];
}
