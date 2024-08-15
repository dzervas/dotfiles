_: {
  hardware.bluetooth = {
    enable = true;
    powerOnBoot = true;
  };

  boot.kernelParams = [ "btusb.enable_autosuspend=n" ];

  # Needed for home-manager's blueman
  services.blueman.enable = true;
}
