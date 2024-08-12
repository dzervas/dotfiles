{ config, pkgs, ... }: {
  imports = [ ./system ];

  system.copySystemConfiguration = false;
  # environment.systemPackages = [ agenix.packages.x86_64-linux.default ];

  users.users.dzervas = {
    isNormalUser = true;
    extraGroups = [ "wheel" "audio" "video" "uucp" "uinput" "vboxusers" "i2c" ];
    shell = pkgs.fish;
  };

  home-manager = {
    useGlobalPkgs = true;
    useUserPackages = true;
    users.dzervas = import ./home;
  };

  systemd.services."getty@tty1" = {
    overrideStrategy = "asDropin";
    serviceConfig.ExecStart = ["" "@${pkgs.util-linux}/sbin/agetty agetty --login-program ${config.services.getty.loginProgram} --autologin dzervas --noclear --keep-baud %I 115200,38400,9600 $TERM"];
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
  programs.dconf.enable = true;

  hardware.enableAllFirmware = true;

  # Fix flatpak default browser
  systemd.user.extraConfig = "DefaultEnvironment=\"PATH=/run/current-system/sw/bin\"";

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
