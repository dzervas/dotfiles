_: {
  services.xserver.videoDrivers = [ "nvidia" ];

  boot = {
    kernelModules = [ "kvm-amd" ];
    # Fixes white flickering after resume/unlock
    kernelParams = [ "amdgpu.sg_display=0" ];
    initrd.kernelModules = [ "amdgpu" ];
  };

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
