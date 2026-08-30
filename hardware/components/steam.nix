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
      # Broken: requires elevated access every time
      enable = true;
      enableRenice = true;
      settings = {
        general.renice = 10;

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
      capSysNice = true;
      enableWsi = true; # Vulkan Window Subsystem Integration
    };

    # NOTE: `echo unShaderBackgroundProcessingThreads 32 >> ~/.local/share/Steam/steam_dev.cfg` to raise the number of threads processing the Vulkan shaders
    steam = {
      enable = true;
      # remotePlay.openFirewall = true; # Open ports in the firewall for Steam Remote Play
      localNetworkGameTransfers.openFirewall = true; # Open ports in the firewall for Steam Local Network Game Transfers
      protontricks.enable = true;
      extest.enable = true; # Steam input on wayland

      extraCompatPackages = with pkgs; [
        proton-ge-bin
        # wine-discord-ipc-bridge # Broken
      ];

      gamescopeSession = {
        enable = true;
        args = [
          "--fullscreen"
          "--steam"
          "--prefer-output" "DP-3"

          # Realtime governor
          "--rt"

          # Screen specific stuff
          "--adaptive-sync"
          # "--mangoapp"
        ];
      };
    };
  };
}
