{ pkgs, ... }:
{
  home-manager.sharedModules = [ ./home/niri.nix ];

  niri-flake.cache.enable = false;
  programs.niri = {
    enable = true;
    package = pkgs.niri;
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
}
