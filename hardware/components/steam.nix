{ pkgs, ... }: {
    # Steam udev rules
  hardware.steam-hardware.enable = true;

  environment.systemPackages = with pkgs; [
    steam-rom-manager
    mangohud
  ];

  # services.joycond.enable = true;

  programs = {
    # joycond-cemuhook.enable = true;

    gamemode = {
      enable = true;
      enableRenice = true;
      settings = {
        general = {
          renice = 10;
        };

        # Warning: GPU optimisations have the potential to damage hardware
        gpu = {
          apply_gpu_optimisations = "accept-responsibility";
          gpu_device = 0;
          amd_performance_level = "high";
        };

        custom = {
          start = "${pkgs.libnotify}/bin/notify-send 'GameMode started'";
          end = "${pkgs.libnotify}/bin/notify-send 'GameMode ended'";
        };
      };
    };

    gamescope = {
      enable = true;
      capSysNice = false;
      args = [
        # TODO: Move to wayland-fixes
        "--backend" "wayland"
        "--fullscreen"

        # Realtime governor
        "--rt"

        # Screen specific stuff
        "--hdr-enabled" "--adaptive-sync"
        # "--mangoapp"
      ];
    };

    steam = {
      enable = true;
      remotePlay.openFirewall = true; # Open ports in the firewall for Steam Remote Play
      localNetworkGameTransfers.openFirewall = true; # Open ports in the firewall for Steam Local Network Game Transfers
      protontricks.enable = true;
    };
  };
}
