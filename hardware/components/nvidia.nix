_: {
  imports = [ ./nvidia-booted-userspace.nix ];

  services.xserver.videoDrivers = [ "nvidia" ];

  # Baloons the initrd image
  # boot.initrd.kernelModules = [ "nvidia" ];

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
