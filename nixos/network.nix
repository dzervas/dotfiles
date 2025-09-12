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

  time.timeZone = "Europe/Athens";

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
      # Bug workaround: https://github.com/NixOS/nixpkgs/issues/438765
      package = pkgs.tailscale.overrideAttrs { doCheck = false; };
      openFirewall = true;
    };
  };

  # Fix Tailscale connectivity after suspend/resume
  systemd.services."tailscale-resume" = {
    description = "Restart Tailscale after resume";
    after = [ "suspend.target" "hibernate.target" "hybrid-sleep.target" ];
    wantedBy = [ "suspend.target" "hibernate.target" "hybrid-sleep.target" ];
    serviceConfig = {
      Type = "oneshot";
      ExecStart = "${pkgs.systemd}/bin/systemctl restart tailscaled.service";
    };
  };
}
