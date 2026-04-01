{ pkgs, ... }: {
  networking = {
    # nameservers = [ "8.8.8.8" "1.1.1.1" ];

    networkmanager = {
      enable = true;
      # Use systemd-resolved so that DNS can be split based on the domains:
      # tailscale for its subdomains
      # local dns for any search domains
      # cloudflare for everything else
      dns = "systemd-resolved";
      appendNameservers = [ "8.8.8.8" "1.1.1.1" ];
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
    network.wait-online.enable = false;
    services.NetworkManager-wait-online.enable = false;

    # Fix Tailscale connectivity after suspend/resume
    services."tailscaled-resume" = {
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
      settings.Resolve = {
        # Global fallback DNS
        # FallbackDns = config.networking.nameservers;
        # Stuff break with forced dnssec :/
        # dnssec = "allow-downgrade";
        DNSOverTLS = "opportunistic";
      };
    };

    tailscale = {
      enable = true;
      openFirewall = true;
      disableUpstreamLogging = true;
      disableTaildrop = true;
      extraDaemonFlags = [ "--no-logs-no-support" ];
    };

    printing = {
      enable = true;
      drivers = with pkgs; [ brlaser ];
    };

    # resolved already handles this
    avahi.enable = false;
  };

  # Broken package
  # boot.extraModulePackages = with config.boot.kernelPackages; [
  #   rtl88xxau-aircrack
  # ];

  time.timeZone = "Europe/Athens";
}
