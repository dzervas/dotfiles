_: {
  # Disable light sensor & accelerometer
  hardware.sensor.iio.enable = false;

  # Say to home-manager that we're a laptop
  home-manager.sharedModules = [{ setup.isLaptop = true; }];

  powerManagement = {
    enable = true;
    powertop.enable = true;
    cpuFreqGovernor = "powersave";
  };

  services = {
    thermald.enable = true;
    power-profiles-daemon.enable = false;
    auto-cpufreq = {
      enable = true;
      settings = {
        battery = {
          governor = "powersave";
          turbo = "never";
        };
        charger = {
          governor = "powersave";
          turbo = "auto";
        };
      };
    };

    libinput = {
      enable = true;
      touchpad.tapping = true;
      touchpad.tappingDragLock = true;
    };
    system76-scheduler = {
      enable = true;
      useStockConfig = true;
    };
  };
}
