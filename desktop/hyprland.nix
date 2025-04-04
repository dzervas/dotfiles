{ inputs, lib, pkgs, ... }: {
  home-manager.sharedModules = [ ./home/hyprland.nix ];

  # Issues:
  # - Crashes?
  # - No 1Password rules
  # - No single-window layout
  # - Changing layout changes it to all workspaces?
  # - Doesn't lock after resume
  # - Titlebar even if 1 window in workspace
  # - No mouse binds (move, resize, etc.)
  # - No screenshot
  # - No per-app keyboard layout

  services = {
    # https://wiki.hyprland.org/Useful-Utilities/Systemd-start/#installation
    dbus.implementation = lib.mkForce "dbus";

    displayManager.sddm = {
      enable = true;
      wayland.enable = true;
    };

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
    hyprlock.enable = true;
  };

  nix.settings = {
    substituters = ["https://hyprland.cachix.org"];
    trusted-public-keys = ["hyprland.cachix.org-1:a7pgxzMz7+chwVL3/pzj6jIBMioiJM7ypFP8PwtkuGc="];
  };
}
