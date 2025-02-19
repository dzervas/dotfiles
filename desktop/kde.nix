{ inputs, pkgs, ... }: {
  home-manager.sharedModules = [
    inputs.plasma-manager.homeManagerModules.plasma-manager
    ./home/kde.nix
  ];

  services = {
    xserver.enable = true;
#    xserver.displayManager.sessionCommands = "export KDEWM=${pkgs.i3}/bin/i3";
    displayManager.defaultSession = "plasmax11";
    libinput.enable = true;

    # https://github.com/danth/stylix/issues/74
    displayManager.sddm = {
      enable = true;
      wayland.enable = false;
      settings = {
        X11 = {
          ServerArguments = "-nolisten tcp -dpi 132";
          MinimumVT = 1;
        };
      };
    };
    desktopManager.plasma6.enable = true;
  };

  # environment.plasma6.excludePackages = with pkgs.kdePackages; [
  #   konsole
  #   oxygen
  # ];

  # GTK theming
  programs.dconf.enable = true;

  environment.systemPackages = with pkgs; [
    kdePackages.kirigami
    kdePackages.kirigami-addons
    kdePackages.kirigami-gallery

    libsForQt5.kwalletmanager
    libsForQt5.plasma-systemmonitor
    libsForQt5.spectacle
    libsForQt5.ark
    libsForQt5.bluedevil
    libsForQt5.dolphin
    libsForQt5.dolphin-plugins
    libsForQt5.gwenview
    libsForQt5.okular
    libsForQt5.plasma-browser-integration
    libsForQt5.plasma-disks
    libsForQt5.plasma-nm
    libsForQt5.plasma-pa
    libsForQt5.kate
  ];
}
