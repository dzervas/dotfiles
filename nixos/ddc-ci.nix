{ config, ... }: {
  hardware.i2c.enable = true;

  boot = {
    # DDC/CI
    extraModulePackages = [config.boot.kernelPackages.ddcci-driver];
    kernelModules = ["ddcci_backlight"];
  };
}
