{ lib, pkgs, ... }: {
  imports = [ ./system ];

  system.copySystemConfiguration = false;

  boot.kernel.sysctl."kernel.dmesg_restrict" = false;

  users.users.dzervas = {
    isNormalUser = true;
    extraGroups = [ "wheel" "audio" "video" "uucp" "uinput" "vboxusers" "gamemode" "dialout" "libvirtd" ];
    shell = pkgs.fish;
  };

  home-manager = {
    useGlobalPkgs = true;
    useUserPackages = true;
    users.dzervas = import ./home;
  };

  systemd = {
    # Fix flatpak default browser
    user.extraConfig = "DefaultEnvironment=\"PATH=/run/current-system/sw/bin\"";
  };

  # Fix home-manager xdg desktop portal support
  environment.pathsToLink = [ "/share/xdg-desktop-portal" "/share/applications" ];
  programs = {
    dconf.enable = true;
    nix-ld = {
      enable = true;
      libraries = with pkgs; [];
    };
  };

  hardware.enableAllFirmware = true;

  services = {
    fwupd.enable = true;

    # Serial comms rules (for Arduino n stuff)
    # udev.packages = with pkgs; [ platformio-core.udev ];

    # Better getty
    kmscon = {
      #enable = lib.mkDefault true;
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

  nix = {
    extraOptions = ''
      # Garbage collect when free space is less than 512MB
      min-free = ${toString (512 * 1024 * 1024)}
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
    };
  };
}
