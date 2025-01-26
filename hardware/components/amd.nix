{ pkgs, ... }: {
  services.xserver.videoDrivers = [ "modesetting" ];

  # nixpkgs.config.rocmSupport = true;

  boot = {
    kernelModules = [ "kvm-amd" ];
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
