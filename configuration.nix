{ pkgs, ... }:
{
  imports = [ ./system/common.nix ];

  system.copySystemConfiguration = false;

  users.users.dzervas = {
    isNormalUser = true;
    extraGroups = [ "wheel" "audio" "video" "uucp" "uinput" "vboxusers" ];
    shell = pkgs.fish;
  };

  home-manager = {
    useGlobalPkgs = true;
    useUserPackages = true;
    users.dzervas = import ./home/home.nix;
  };

  # Fix home-manager xdg desktop portal support
  environment.pathsToLink = [ "/share/xdg-desktop-portal" "/share/applications" ];

  services.pipewire = {
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
  services.fwupd.enable = true;

  # Enable flakes


  # Fix flatpak default browser
  # systemd.user.extraConfig = "DefaultEnvironment=\"PATH=/run/current-system/sw/bin\"";

  nix = {
    extraOptions = "min-free = ${toString (50 * 1024 * 1024)}"; # Garbage collect when free space is less than 50MB
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
    };
  };
}
