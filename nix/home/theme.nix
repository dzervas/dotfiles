{ pkgs, lib, ... }: {
  home.packages = with pkgs; [
    papirus-folders
  ];

  dconf.settings = {
    "org/gnome/desktop/background" = {
      picture-uri-dark = "file://${pkgs.nixos-artwork.wallpapers.nineish-dark-gray.src}";
    };
    "org/gnome/desktop/interface" = {
      color-scheme = "prefer-dark";
      # gtk-theme = "Breeze-Dark";
    };
  };

  # gtk = {
  #   enable = true;
  #   theme = {
  #     name = "Breeze-Dark";
  #     package = pkgs.libsForQt5.breeze-gtk;
  #   };
  #   iconTheme = {
  #     name = "Papirus-Dark";
  #     package = pkgs.catppuccin-papirus-folders.override {
  #       flavor = "mocha";
  #       accent = "lavender";
  #     };
  #   };
  #   cursorTheme = {
  #     name = "Catppuccin-Mocha-Light-Cursors";
  #     package = pkgs.catppuccin-cursors.mochaLight;
  #   };
  #   gtk3 = {
  #     extraConfig.gtk-application-prefer-dark-theme = true;
  #   };
  # };

  # xdg.configFile = {
  #   kvantum = {
  #     target = "Kvantum/kvantum.kvconfig";
  #     text = lib.generators.toINI { } {
  #       General.theme = "Catppuccin-Mocha-Blue";
  #     };
  #   };

  #   qt5ct = {
  #     target = "qt5ct/qt5ct.conf";
  #     text = lib.generators.toINI { } {
  #       Appearance = {
  #         icon_theme = "Papirus-Dark";
  #       };
  #     };
  #   };

  #   qt6ct = {
  #     target = "qt6ct/qt6ct.conf";
  #     text = lib.generators.toINI { } {
  #       Appearance = {
  #         icon_theme = "Papirus-Dark";
  #       };
  #     };
  #   };
  # };

  catppuccin = {
    enable = true;
    pointerCursor.enable = true;
  };
  gtk.catppuccin.enable = true;
  qt.style.catppuccin.enable = true;
  wayland.windowManager.sway.catppuccin.enable = true;

  # Wayland, X, etc. support for session vars
  # systemd.user.sessionVariables = config.home-manager.users.justinas.home.sessionVariables;
}