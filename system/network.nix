{ config, ... }: {
  networking.networkmanager.enable = true;
  # networking.wireless.enable = false; # Can't use with networkmanager???

  # Firewall
  networking.firewall.enable = true;
  networking.firewall.allowedTCPPorts = [ 8181 ];

  time.timeZone = "Europe/Athens";

  boot.extraModulePackages = with config.boot.kernelPackages; [
    rtl88xxau-aircrack
  ];
}
