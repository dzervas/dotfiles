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

  environment.systemPackages = with pkgs; [ sbctl ];
}
