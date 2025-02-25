{ config, lib, pkgs, ... }: {
  home-manager.sharedModules = [ ./home/sway.nix ];

  # Issues:
  # - No screen mirroring
  # - Many times copy doesn't work
  # - Sway starts using the tty1 hack (no systemd)
  # - Issues with gnome-keyring

  programs = {
    thunar = {
      enable = true;
      plugins = with pkgs.xfce; [
        thunar-volman
        thunar-archive-plugin
        thunar-media-tags-plugin
      ];
    };
    # Thunar archive manager
    file-roller.enable = true;
    # Save xfce settings
    xfconf.enable = true;
  };

  services = {
    xserver = {
      enable = true;

      # Disable lightdm (it's enabled by default)
      displayManager.lightdm.enable = false;
    };

    displayManager.autoLogin.enable = lib.mkForce false;

    # GNOME Keyring - used by VSCode mainly
    gnome.gnome-keyring.enable = true;

    # XFCE File management
    # Mount, trash and more
    gvfs.enable = true;
    # Thumbnail support
    tumbler.enable = true;

    # Can't start sway
    kmscon.enable = false;
  };

  security = {
    pam = {
      services = {
        swaylock = {};
        login.enableGnomeKeyring = true;
      };

      # faster sway maybe? https://nixos.wiki/wiki/Sway
      loginLimits = [{
        domain = "@users";
        item = "rtprio";
        type = "-";
        value = 1;
      }];
    };
  };

  # XDG Shit
  xdg.portal = {
    enable = true;
    wlr.enable = true;
    configPackages = [ pkgs.xdg-desktop-portal-wlr ];
  };

  systemd.services."getty@tty1" = {
    overrideStrategy = "asDropin";
    serviceConfig.ExecStart = ["" "@${pkgs.util-linux}/sbin/agetty agetty --login-program ${config.services.getty.loginProgram} --autologin dzervas --noclear --keep-baud %I 115200,38400,9600 $TERM"];
  };
}
