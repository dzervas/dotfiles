{ inputs, lib, pkgs, ... }: {
  home-manager.sharedModules = [ ./home/hyprland.nix ];

  services = {
    hypridle.enable = true;
    # https://wiki.hyprland.org/Useful-Utilities/Systemd-start/#installation
    dbus.implementation = lib.mkForce "dbus";

    displayManager.sddm = {
      enable = true;
      wayland.enable = true;
    };
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
