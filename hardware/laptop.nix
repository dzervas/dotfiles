{ config, inputs, pkgs, ... }: let
  cryptroot_part = "/dev/disk/by-label/cryptroot";
  system_fs = "/dev/mapper/cryptroot";
in {
  imports = [
    ./components/amd.nix
    ./components/boot.nix
    ./components/peripherals.nix
    ./components/secure-boot.nix
    # ./components/virtualbox.nix
    ./components/libvirt.nix
    ./components/laptop.nix
    ./components/fingerprint.nix
    inputs.nixos-hardware.nixosModules.framework-13-7040-amd
  ];

  boot = {
    # Add kernel parameters to better support suspend (i.e., "sleep" feature)
    kernelParams = [ "mem_sleep_default=s2idle" "amdgpu.dcdebugmask=0x10" "acpi_mask_gpe=0x1A" "rtc_cmos.use_acpi_alarm=1" ];
    initrd.luks.devices.cryptroot.device = cryptroot_part;
  };

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

  swapDevices = [{ device = "/swapfile"; }];

  services = {
    power-profiles-daemon.enable = true;
    btrfs.autoScrub = {
      enable = true;
      interval = "weekly";
    };
  };

  stylix.image = pkgs.fetchurl {
    # Photo by Dave Hoefler on Unsplash: https://unsplash.com/photos/sunlight-through-trees-hQNY2WP-qY4
    url = "https://unsplash.com/photos/hQNY2WP-qY4/download?ixid=M3wxMjA3fDB8MXxhbGx8fHx8fHx8fHwxNzIwMzUyNTA4fA&force=true";
    sha256 = "sha256-gw+BkfVkuzMEI8ktiLoHiBMupiUS9AoiB+acFTCt36g=";
  };

  environment.systemPackages = with pkgs; [
    powertop
    framework-tool
  ];

  powerManagement = {
    enable = true;
    powertop.enable = true;
  };

  hardware = {
    # Disable light sensor & accelerometer
    sensor.iio.enable = false;

    # https://github.com/NixOS/nixos-hardware/tree/master/framework/13-inch/7040-amd#suspendwake-workaround
    framework.amd-7040.preventWakeOnAC = true;
  };
}
