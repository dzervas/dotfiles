_: {
  services.xserver.videoDrivers = [ "nvidia" ];

  boot.initrd.kernelModules = [ "nvidia" ];

  hardware.nvidia = {
    modesetting.enable = true;
    powerManagement = {
      enable = true;
      finegrained = false;
      kernelSuspendNotifier = true;
    };
    open = true;
    nvidiaSettings = true;
  };

  hardware.nvidia-container-toolkit.enable = true;
}
