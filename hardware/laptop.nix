{ inputs, pkgs, ... }: let
  cryptroot_part = "/dev/disk/by-label/cryptroot";
  system_fs = "/dev/mapper/cryptroot";
in {
  imports = [
    ./components/amd.nix
    ./components/boot.nix
    # ./components/libvirt.nix
    ./components/peripherals.nix
    ./components/secure-boot.nix
    ./components/steam.nix

    # Laptop
    ./components/fingerprint.nix
    ./components/laptop.nix

    inputs.nixos-hardware.nixosModules.framework-13-7040-amd
  ];

  boot = {
    # Add kernel parameters to better support suspend (i.e., "sleep" feature)
    kernelParams = [
      "mem_sleep_default=s2idle"
      "amdgpu.dcdebugmask=0x10"
      "acpi_mask_gpe=0x1A"
      "rtc_cmos.use_acpi_alarm=1"
      # /swapfile offset - found with:
      # sudo btrfs inspect-internal map-swapfile -r /swapfile
      "resume_offset=23903603"
    ];
    initrd.luks.devices.cryptroot.device = cryptroot_part;

    resumeDevice = system_fs;
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
      options = [
        "subvol=nix"

        # Nix store optimizations
        "noatime" # Don't keep access times
        "nodiratime" # Ditto for directories
        "discard=async" # Asynchronously discard old files with SSD TRIM operations
        "compress=zstd:3" # Compress the files - even with level 3 a ratio of ~2 is expected
      ];
    };
  };

  swapDevices = [{ device = "/swapfile"; }];

  # Actually hardware-specific
  environment.systemPackages = with pkgs; [ framework-tool ];

  # https://github.com/NixOS/nixos-hardware/tree/master/framework/13-inch/7040-amd#suspendwake-workaround
  hardware.framework.amd-7040.preventWakeOnAC = true;

  stylix.image = pkgs.fetchurl {
    # Photo by Dave Hoefler on Unsplash: https://unsplash.com/photos/sunlight-through-trees-hQNY2WP-qY4
    url = "https://unsplash.com/photos/hQNY2WP-qY4/download?ixid=M3wxMjA3fDB8MXxhbGx8fHx8fHx8fHwxNzIwMzUyNTA4fA&force=true";
    sha256 = "sha256-gw+BkfVkuzMEI8ktiLoHiBMupiUS9AoiB+acFTCt36g=";
  };
}
