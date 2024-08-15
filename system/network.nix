{ config, ... }: {
  networking = {
    networkmanager.enable = true;
    wireless.enable = false; # Can't use with networkmanager???

    firewall = {
      enable = true;
      allowedTCPPorts = [ 8181 ];
    };
  };

  time.timeZone = "Europe/Athens";

  boot.extraModulePackages = with config.boot.kernelPackages; [
    rtl88xxau-aircrack
  ];
}
