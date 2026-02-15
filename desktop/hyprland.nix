{ inputs, pkgs, ... }:
{
  home-manager.sharedModules = [ ./home/hyprland.nix ];

  # Issues:
  # - 1Password rules

  environment.systemPackages = [ pkgs.file-roller ];

  services = {
    # https://wiki.hyprland.org/Useful-Utilities/Systemd-start/#installation
    dbus.implementation = "broker";

    # Maybe greetd instead? https://github.com/XNM1/linux-nixos-hyprland-config-dotfiles/blob/main/nixos/display-manager.nix
    displayManager.sddm = {
      enable = true;
      # theme = "chili";
      # extraPackages = [ pkgs.sddm-chili-theme ]; # Broken
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
    hyprland = {
      enable = true;
      package = inputs.hyprland.packages.${pkgs.stdenv.hostPlatform.system}.hyprland;
      portalPackage =
        inputs.hyprland.packages.${pkgs.stdenv.hostPlatform.system}.xdg-desktop-portal-hyprland;
      # withUWSM = true; # Results in the podman-in-zed crash
    };

    thunar = {
      enable = true;
      plugins = with pkgs; [
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

  # https://wiki.hypr.land/Nix/Hyprland-on-Home-Manager/#using-the-home-manager-module-with-nixos
  # xdg.configFile."uwsm/env".source = "${config.home.sessionVariablesPackage}/etc/profile.d/hm-session-vars.sh";
}
