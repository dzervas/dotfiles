{ config, pkgs, ... }: {
  networking = {
    networkmanager.enable = true;
    wireless.enable = false; # Can't use with networkmanager???

    firewall = {
      enable = true;
      allowedTCPPorts = [
        # Generic ports
        8181
      ];
    };
  };

  systemd.services.NetworkManager-wait-online.enable = false;

  time.timeZone = "Europe/London";

  boot.extraModulePackages = with config.boot.kernelPackages; [
    rtl88xxau-aircrack
  ];

  services = {
    printing = {
      enable = true;
      drivers = with pkgs; [ brlaser ];
    };
    avahi = {
      enable = true;
      nssmdns4 = true;
      ipv6 = false;
      denyInterfaces = ["zt+" "tailscale+"];
    };

    tailscale = {
      enable = true;
      openFirewall = true;
    };
  };
}
