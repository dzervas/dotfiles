{ ... }: {
  powerManagement.enable = true;

  services.libinput = {
    enable = true;
    touchpad.tapping = true;
    touchpad.tappingDragLock = true;
  };

  hardware.fancontrol.enable = true;
}
