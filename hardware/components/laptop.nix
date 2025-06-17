_: {
  # Disable light sensor & accelerometer
  hardware.sensor.iio.enable = false;

  # Say to home-manager that we're a laptop
  home-manager.sharedModules = [{ setup.isLaptop = true; }];

  powerManagement = {
    enable = true;
    powertop.enable = true;
  };

  services.libinput = {
    enable = true;
    touchpad.tapping = true;
    touchpad.tappingDragLock = true;
  };
}
