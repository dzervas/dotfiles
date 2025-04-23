{ inputs, lib, pkgs, ... }: {
  home-manager.sharedModules = [ ./home/hyprland.nix ];

  # Issues:
  # - 1Password rules

  environment.systemPackages = [ pkgs.sddm-chili-theme ]; # SDDM theme

  services = {
    # https://wiki.hyprland.org/Useful-Utilities/Systemd-start/#installation
    dbus.implementation = lib.mkForce "dbus";

    displayManager.sddm = {
      enable = true;
      theme = "chili";
      wayland.enable = true;
    };

    # XFCE File management
    # Mount, trash and more
    gvfs.enable = true;
    # Thumbnail support
    tumbler.enable = true;

    # GNOME Keyring - used by VSCode mainly
    gnome.gnome-keyring.enable = true;
  };

  programs = {
    uwsm.enable = true;

    hyprland = {
      enable = true;
      package = inputs.hyprland.packages.${pkgs.stdenv.hostPlatform.system}.hyprland;
      portalPackage = inputs.hyprland.packages.${pkgs.stdenv.hostPlatform.system}.xdg-desktop-portal-hyprland;
      withUWSM = true;
    };

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

  security.pam.services.login.enableGnomeKeyring = true;

  nix.settings = {
    substituters = ["https://hyprland.cachix.org"];
    trusted-public-keys = ["hyprland.cachix.org-1:a7pgxzMz7+chwVL3/pzj6jIBMioiJM7ypFP8PwtkuGc="];
  };
}
