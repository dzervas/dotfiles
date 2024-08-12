{ config, lib, pkgs, ... }: {
  services.xserver.enable = true;
  hardware.graphics.enable = true;
  security.polkit.enable = true;
  services.displayManager = {
    autoLogin.enable = lib.mkForce false;
    # sddm.enable = true;
    # sddm.wayland.enable = true;
  };

  programs.sway = {
    enable = true;
    wrapperFeatures.gtk = true;
  };

  # faster sway maybe? https://nixos.wiki/wiki/Sway
  security.pam.loginLimits = [{
    domain = "@users";
    item = "rtprio";
    type = "-";
    value = 1;
  }];

  security.pam.services.login.enableGnomeKeyring = true;
  services.gnome.gnome-keyring.enable = true;

  # Electron fix - https://nixos.wiki/wiki/Wayland#Electron_and_Chromium
  environment.sessionVariables.NIXOS_OZONE_WL = "1";

  environment.systemPackages = with pkgs; [
    gthumb
    libsecret
  ];

  # Brightness control
  programs.light.enable = true;
  hardware.i2c.enable = true;
  boot.extraModulePackages = [config.boot.kernelPackages.ddcci-driver];
  boot.kernelModules = ["ddcci_backlight"];

  # FlatPak
  services.flatpak.enable = true;
  services.accounts-daemon.enable = true; # Flatpak needs this

  # XDG Shit
  xdg.portal = {
    enable = true;
    wlr.enable = true;
  };

  # File manager - home-manager doesn't have it
  programs.thunar = {
    enable = true;
    plugins = with pkgs.xfce; [
      thunar-volman
      thunar-archive-plugin
      thunar-media-tags-plugin
    ];
  };
  programs.file-roller.enable = true;
  # Mount, trash and more
  services.gvfs.enable = true;
  # Thumbnail support
  services.tumbler.enable = true;
  # Save xfce settings
  programs.xfconf.enable = true;
  # Needed for home-manager's blueman
  services.blueman.enable = true;

  # Steam udev rules
  hardware.steam-hardware.enable = true;

  # Disable lightdm (it's enabled by default)
  services.xserver.displayManager.lightdm.enable = false;
}
