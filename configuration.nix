{ config, pkgs, ... }: {
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
#    services."getty@tty1" = {
#      overrideStrategy = "asDropin";
#      serviceConfig.ExecStart = ["" "@${pkgs.util-linux}/sbin/agetty agetty --login-program ${config.services.getty.loginProgram} --autologin dzervas --noclear --keep-baud %I 115200,38400,9600 $TERM"];
#    };

    # Fix flatpak default browser
    user.extraConfig = "DefaultEnvironment=\"PATH=/run/current-system/sw/bin\"";
  };

  # Fix home-manager xdg desktop portal support
  environment.pathsToLink = [ "/share/xdg-desktop-portal" "/share/applications" ];
  programs.dconf.enable = true;

  hardware.enableAllFirmware = true;

  services = {
    fwupd.enable = true;

    # Serial comms rules (for Arduino n stuff)
    udev.packages = with pkgs; [ platformio-core.udev ];

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
    extraOptions = "min-free = ${toString (512 * 1024 * 1024)}"; # Garbage collect when free space is less than 512MB
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
      substituters = ["https://hyprland.cachix.org"];
      trusted-public-keys = ["hyprland.cachix.org-1:a7pgxzMz7+chwVL3/pzj6jIBMioiJM7ypFP8PwtkuGc="];
    };
  };
}
