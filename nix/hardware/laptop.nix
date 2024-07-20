{ ... }: let
  root_disk = "/dev/disk/by-uuid/3153b379-9bc8-48e0-baa8-5e9ba59db081";
  cryptroot_disk = "/dev/disk/by-uuid/554c3697-ff49-4f1c-af96-69624a12910b";
in {
  imports = [
    ./components/amd.nix
    ./components/efi-luks.nix
    ./components/laptop.nix
  ];

  boot.initrd.luks.devices.cryptroot.device = root_disk;

  # Generated using nix-shell -p lm_sensors --run pwmconfig
  hardware.fancontrol.config = ''
    # Configuration file generated by pwmconfig, changes will be lost
    INTERVAL=10
    DEVPATH=hwmon0=devices/pci0000:00/0000:00:08.1/0000:03:00.0 hwmon6=devices/platform/dell_smm_hwmon
    DEVNAME=hwmon0=amdgpu hwmon6=dell_smm
    FCTEMPS=hwmon6/pwm1=hwmon0/temp1_input
    FCFANS= hwmon6/pwm1=hwmon6/fan1_input
    MINTEMP=hwmon6/pwm1=35
    MAXTEMP=hwmon6/pwm1=65
    MINSTART=hwmon6/pwm1=150
    MINSTOP=hwmon6/pwm1=0
  '';


  fileSystems = {
    "/" = {
      device = cryptroot_disk;
      fsType = "btrfs";
      options = [ "subvol=root" ];
    };
    "/home" = {
      device = cryptroot_disk;
      fsType = "btrfs";
      options = [ "subvol=home" ];
    };
    "/nix" = {
      device = cryptroot_disk;
      fsType = "btrfs";
      options = [ "subvol=nix" ];
    };

    "/boot" = {
      device = "/dev/disk/by-label/BOOT"; # replace with your actual EFI partition UUID
      fsType = "vfat";
    };
  };

  swapDevices = [{ device = "/swap/swapfile"; }];

  services.btrfs.autoScrub = {
    enable = true;
    interval = "weekly";
  };
}
