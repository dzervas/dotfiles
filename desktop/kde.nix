{ inputs, pkgs, ... }: {
  home-manager.sharedModules = [
    inputs.plasma-manager.homeManagerModules.plasma-manager
    ./home/kde.nix
  ];

  services = {
    xserver.enable = true;
#    xserver.displayManager.sessionCommands = "export KDEWM=${pkgs.i3}/bin/i3";
    displayManager.sddm.enable = true;
    desktopManager.plasma6.enable = true;
  };

  environment.plasma6.excludePackages = with pkgs.kdePackages; [
    konsole
    oxygen
  ];

  # GTK theming
  programs.dconf.enable = true;
}
