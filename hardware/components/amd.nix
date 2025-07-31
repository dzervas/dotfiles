{ pkgs, ... }: {
  services.xserver.videoDrivers = [ "amdgpu" ];

  # Results in an error:
  # nixpkgs.config.rocmSupport = true;

  boot = {
    kernelModules = [ "kvm-amd" ];
    # Fixes white flickering after resume/unlock
    kernelParams = [ "amdgpu.sg_display=0" ];
    initrd.kernelModules = [ "amdgpu" ];
  };

  hardware = {
    amdgpu.initrd.enable = true;
    cpu.amd.updateMicrocode = true;
    enableRedistributableFirmware = true;

    graphics.extraPackages = with pkgs; [
      mesa
      rocmPackages.clr.icd
    ];
  };
}
