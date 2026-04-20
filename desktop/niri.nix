{ pkgs, ... }:
{
  home-manager.sharedModules = [ ./home/niri.nix ];

  niri-flake.cache.enable = false;

  programs.niri = {
    enable = true;
    package = pkgs.niri-unstable;
  };

  services = {
    dbus.implementation = "broker";
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
  };

  security.pam.services.login.enableGnomeKeyring = true;
  environment.systemPackages = with pkgs; [
    file-roller
    nautilus
  ];
  services.gnome.sushi.enable = true;
  # Calendar events - https://docs.noctalia.dev/getting-started/nixos/#calendar-events-support
  services.gnome.evolution-data-server.enable = true;
}
