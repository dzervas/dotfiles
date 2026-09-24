{ config, pkgs, ... }: {
  environment.systemPackages = with pkgs; [
    wireguard-tools
  ];

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
      unmanaged = ["zt+" "tailscale+" "tun+" "homelab0"];
    };

    firewall = {
      enable = true;
      allowedTCPPorts = [
        # Generic ports
        8181
      ];
    };

    wireguard.interfaces.homelab0 = {
      privateKeyFile = "/etc/wireguard-homelab-privkey";
      dynamicEndpointRefreshSeconds = 50;
      mtu = 1300;
      ips = [(
        if config.networking.hostName == "desktop" then "10.50.50.4"
        else if config.networking.hostName == "laptop" then "10.50.50.5"
        else ""
      )];
      peers = [
        {
          allowedIPs = ["10.50.50.0/24" "10.43.0.0/24"];
          endpoint = "wg.dzerv.art:25820";
          publicKey = "WMQJuh8heXBILop4k0AM53XM7/Q5xyy1Y03c3nGG7DU=";
          persistentKeepalive = 25;
        }
      ];
    };
  };

  systemd = {
    network.wait-online.enable = false;
    services.NetworkManager-wait-online.enable = false;
  };

  services = {
    resolved = {
      enable = true;
      dnsDelegates.homelab0.Delegate = {
        Domains = "~vpn.dzerv.art";
        DNS = "10.43.0.53";
      };
      settings.Resolve = {
        # Global fallback DNS
        # FallbackDns = config.networking.nameservers;
        # Stuff break with forced dnssec :/
        # dnssec = "allow-downgrade";
        DNSOverTLS = "opportunistic";

        MulticastDNS = false; # Avahi owns mDNS, both on port 5353 conflict
      };
    };

    printing = {
      enable = true;
      drivers = with pkgs; [ brlaser ];
    };

    avahi = {
      enable = true;
      nssmdns4 = true;     # resolve *.local hostnames
      openFirewall = true; # UDP 5353, otherwise mDNS replies get dropped
    };
    netclient.enable = true;
  };

  # Broken package
  # boot.extraModulePackages = with config.boot.kernelPackages; [
  #   rtl88xxau-aircrack
  # ];

  time.timeZone = "Europe/Athens";
}
