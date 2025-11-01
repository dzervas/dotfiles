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
    amdgpu = {
      initrd.enable = true;
      opencl.enable = true;
    };

    cpu.amd.updateMicrocode = true;
    enableRedistributableFirmware = true;

    graphics.extraPackages = with pkgs; [
      mesa
      rocmPackages.clr
      rocmPackages.clr.icd
      rocmPackages.rocblas
      rocmPackages.rpp
      nvtopPackages.amd
    ];
  };

  # Configure /opt/rocm symlink for ROCm hardcoded paths
  systemd.tmpfiles.rules = let
    rocmEnv = pkgs.symlinkJoin {
      name = "rocm-combined";
      paths = with pkgs.rocmPackages; [
        clr
        clr.icd
        rocblas
        hip
        hipblas
        rpp
        rocm-smi
        rocm-device-libs
      ];
    };
  in ["L+    /opt/rocm   -    -    -     -    ${rocmEnv}"];

  environment.variables = {
    ROCM_PATH = "/opt/rocm";                   # Set ROCm path
    HIP_VISIBLE_DEVICES = "1";                 # Use only the eGPU (ID 1)
    ROCM_VISIBLE_DEVICES = "1";                # Optional: ROCm equivalent for visibility
    LD_LIBRARY_PATH = "/opt/rocm/lib";         # Add ROCm libraries
    HSA_OVERRIDE_GFX_VERSION = "10.3.0";       # Set GFX version override (5700XT)
  };
}
