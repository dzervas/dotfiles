{ inputs, pkgs, ... }: {
  home-manager.sharedModules = [
    inputs.plasma-manager.homeManagerModules.plasma-manager
    ./home/kde.nix
  ];

  services = {
    xserver = {
      enable = true;
      desktopManager.plasma5.enable = true;
    };
    displayManager.defaultSession = "plasma";
    libinput.enable = true;

    # https://github.com/danth/stylix/issues/74
    displayManager.sddm = {
      enable = true;
      wayland.enable = false;
      settings = {
        X11 = {
          ServerArguments = "-nolisten tcp";
          MinimumVT = 1;
        };
      };
    };
  };

  # GTK theming
  programs.dconf.enable = true;

  environment.systemPackages = with pkgs; [
    kdePackages.kirigami
    kdePackages.kirigami-addons
    kdePackages.kirigami-gallery

    kdePackages.kwalletmanager
    kdePackages.plasma-systemmonitor
    kdePackages.spectacle
    kdePackages.ark
    kdePackages.bluedevil
    kdePackages.dolphin
    kdePackages.dolphin-plugins
    kdePackages.gwenview
    kdePackages.okular
    kdePackages.plasma-browser-integration
    kdePackages.plasma-disks
    kdePackages.plasma-nm
    kdePackages.plasma-pa
    kdePackages.kate

    xdotool
    xclip
    xsel
  ];
}
