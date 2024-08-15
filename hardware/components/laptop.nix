_: {
  powerManagement.enable = true;

  services.libinput = {
    enable = true;
    touchpad.tapping = true;
    touchpad.tappingDragLock = true;
  };

  hardware.fancontrol.enable = true;

  # Say to home-manager that we're a laptop
  home-manager.sharedModules = [{ setup.isLaptop = true; }];
}
