{ lib, pkgs, ... }: {
  hardware = {
    graphics.enable = true;

    # Steam udev rules
    steam-hardware.enable = true;
  };

  environment = {
    # Electron fix - https://nixos.wiki/wiki/Wayland#Electron_and_Chromium
    sessionVariables.NIXOS_OZONE_WL = "1";

    systemPackages = with pkgs; [
      gthumb
      libsecret
    ];
  };

  programs = {
    # File manager - home-manager doesn't have it
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

    # Backlight/brightness control
    light.enable = true;

    # Gaming optimizations
    gamemode.enable = true;
    gamescope.enable = true;
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

    # FlatPak
    flatpak.enable = true;
    accounts-daemon.enable = true; # Flatpak needs this

    # XFCE File management
    # Mount, trash and more
    gvfs.enable = true;
    # Thumbnail support
    tumbler.enable = true;
  };

  security = {
    polkit.enable = true;
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
}
