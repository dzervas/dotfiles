{ config, pkgs, ... }: {
  networking = {
    useNetworkd = true;
    nameservers = [ "8.8.8.8" "1.1.1.1" ];
    networkmanager = {
      enable = true;
      # Use systemd-resolved so that DNS can be split based on the domains:
      # tailscale for its subdomains
      # local dns for any search domains
      # cloudflare for everything else
      dns = "systemd-resolved";
      unmanaged = ["zt+" "tailscale+" "tun+"];
    };

    firewall = {
      enable = true;
      allowedTCPPorts = [
        # Generic ports
        8181
      ];
    };
  };

  systemd = {
    # Use magic dns only for the tailscale subdomains
    network = {
      wait-online.enable = false;
      networks."tailscale0" = {
        matchConfig.Name = "tailscale0";
        dns = [ "100.100.100.100" ];
        domains = [ "~ts.dzerv.art" ];
      };
    };

    services.NetworkManager-wait-online.enable = false;

    # Fix Tailscale connectivity after suspend/resume
    services."tailscale-resume" = {
      description = "Restart Tailscale after resume";
      after = [ "suspend.target" "hibernate.target" "hybrid-sleep.target" ];
      wantedBy = [ "suspend.target" "hibernate.target" "hybrid-sleep.target" ];
      serviceConfig = {
        Type = "oneshot";
        ExecStart = "${pkgs.systemd}/bin/systemctl restart tailscaled.service";
      };
    };
  };

  services = {
    resolved = {
      enable = true;
      # Global fallback DNS
      fallbackDns = config.networking.nameservers;
      # Stuff break with forced dnssec :/
      # dnssec = "allow-downgrade";
      dnsovertls = "opportunistic";
      domains = [ "~." ]; # ensure systemd-resolved is the default resolver
    };

    tailscale = {
      enable = true;
      openFirewall = true;
    };

    printing = {
      enable = true;
      drivers = with pkgs; [ brlaser ];
    };

    # resolved already handles this
    avahi.enable = false;
  };

  boot.extraModulePackages = with config.boot.kernelPackages; [
    rtl88xxau-aircrack
  ];

  time.timeZone = "Europe/Athens";
}
