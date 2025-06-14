{ config, pkgs, ... }: {
  imports = [ ./system ];

  system.copySystemConfiguration = false;

  # Allow rootless dmesg
  boot.kernel.sysctl."kernel.dmesg_restrict" = false;

  users.users.dzervas = {
    isNormalUser = true;
    extraGroups = [ "wheel" "audio" "video" "uucp" "uinput" "vboxusers" "gamemode" "dialout" "libvirtd" "podman" ];
    shell = pkgs.fish;
  };

  home-manager = {
    useGlobalPkgs = true;
    useUserPackages = true;
    users.dzervas = import ./home;
  };

# Fix flatpak default browser
  systemd.user.extraConfig = "DefaultEnvironment=\"PATH=/run/current-system/sw/bin\"";

  # Fix home-manager xdg desktop portal support
  environment.pathsToLink = [ "/share/xdg-desktop-portal" "/share/applications" ];
  programs = {
    dconf.enable = true;
    nix-ld = {
      enable = true;
      # libraries = with pkgs; [];
    };
  };

  hardware.enableAllFirmware = true;

  services = {
    fwupd.enable = true;

    # Serial comms rules (for Arduino n stuff)
    udev.packages = with pkgs; [ platformio-core.udev ];

    # Better getty
    kmscon = {
      #enable = lib.mkDefault true;
      fonts = [ config.stylix.fonts.monospace ];
      useXkbConfig = true;
      hwRender = true;
      extraConfig = ''
xkb-layout=us,gr
xkb-options=grp:alt_space_toggle,caps:escape
      '';
    };

    pipewire = {
      enable = true;
      pulse.enable = true;
      wireplumber = {
        enable = true;
        extraConfig = {
          "51-disable-hfp" = {
            "wireplumber.settings" = {
              "bluetooth.autoswitch-to-headset-profile" = false;
            };
            "monitor.bluez.properties" = {
              "bluez5.roles" = [ "a2dp_sink" "a2dp_source" ];
            };
          };
        };
      };
    };
  };

  security = {
    audit.enable = true;
    auditd.enable = true;
    pam.services = {
      root.ttyAudit.enable = true;
      dzervas.ttyAudit.enable = true;
    };
  };

  nix = {
    extraOptions = ''
      # Garbage collect when free space is less than 32GB
      min-free = ${toString (32 * 1024 * 1024 * 1024)}
    '';
    gc = {
      automatic = true;
      dates = "weekly";
      options = "--delete-older-than 10d";
    };
    optimise = {
      automatic = true;
      dates = [ "weekly" ];
    };
    settings = {
      experimental-features = [ "nix-command" "flakes" ];
      warn-dirty = false;
      keep-outputs = true;
      max-jobs = "auto";
      cores = 0;  # Use all available cores
      build-cores = 0;
    };
  };
}
