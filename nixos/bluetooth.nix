_: {
  hardware.bluetooth = {
    enable = true;
    powerOnBoot = true;
    settings.General.Experimental = true;
  };

  boot.kernelParams = [ "btusb.enable_autosuspend=n" ];

  # Needed for home-manager's blueman
  services.blueman.enable = true;

  # Better Xbox gamepad driver
  hardware.xpadneo.enable = true;
}
