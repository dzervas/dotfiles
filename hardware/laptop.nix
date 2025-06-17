{ inputs, pkgs, ... }: let
  cryptroot_part = "/dev/disk/by-label/cryptroot";
  system_fs = "/dev/mapper/cryptroot";
in {
  imports = [
    ./components/amd.nix
    ./components/boot.nix
    ./components/libvirt.nix
    ./components/peripherals.nix
    ./components/secure-boot.nix

    # Laptop
    ./components/fingerprint.nix
    ./components/laptop.nix

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
  };

  swapDevices = [{ device = "/swapfile"; }];

  # Actually hardware-specific
  environment.systemPackages = with pkgs; [ framework-tool ];
  services.power-profiles-daemon.enable = true;

  # https://github.com/NixOS/nixos-hardware/tree/master/framework/13-inch/7040-amd#suspendwake-workaround
  hardware.framework.amd-7040.preventWakeOnAC = true;

  stylix.image = pkgs.fetchurl {
    # Photo by Dave Hoefler on Unsplash: https://unsplash.com/photos/sunlight-through-trees-hQNY2WP-qY4
    url = "https://unsplash.com/photos/hQNY2WP-qY4/download?ixid=M3wxMjA3fDB8MXxhbGx8fHx8fHx8fHwxNzIwMzUyNTA4fA&force=true";
    sha256 = "sha256-gw+BkfVkuzMEI8ktiLoHiBMupiUS9AoiB+acFTCt36g=";
  };
}
