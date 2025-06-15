{ config, pkgs, ... }: {
  networking = {
    networkmanager.enable = true;
    wireless.enable = false; # Can't use with networkmanager???

    firewall = {
      enable = true;
      allowedTCPPorts = [
        # Generic ports
        8181

        # Steam remote-play
        27036
        # Steam local data transfers
        27040
      ];

      allowedUDPPorts = [
        # Steam peer discovery
        27036
      ];

      # Steam remote-play
      allowedUDPPortRanges = [ { from = 27031; to = 27035; } ];
    };
  };

  systemd.services.NetworkManager-wait-online.enable = false;

  time.timeZone = "Europe/Athens";

  boot.extraModulePackages = with config.boot.kernelPackages; [
    rtl88xxau-aircrack
  ];

  programs.kdeconnect.enable = true;

  services = {
    printing = {
      enable = true;
      drivers = with pkgs; [ brlaser ];
    };
    avahi = {
      enable = true;
      nssmdns4 = true;
      ipv6 = false;
      denyInterfaces = ["zt+"];
    };
  };
}
