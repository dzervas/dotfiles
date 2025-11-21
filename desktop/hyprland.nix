{ inputs, lib, pkgs, ... }: {
  home-manager.sharedModules = [ ./home/hyprland.nix ];

  # Issues:
  # - 1Password rules
  # - Podman crash

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
        thunar-vcs-plugin
      ];
    };
    # Thunar archive manager
    # file-roller.enable = true;
    # Save xfce settings
    xfconf.enable = true;
  };

  security.pam.services.login.enableGnomeKeyring = true;
}
