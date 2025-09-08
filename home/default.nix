{ config, pkgs, ... }: {
  imports = [
    ./1password.nix
    ./ai.nix
    ./atuin.nix
    ./chromium.nix
    ./dev.nix
    ./direnv.nix
    ./easyeffects
    ./firefox.nix
    ./firmware.nix
    ./fish.nix
    ./flatpak.nix
    ./git.nix
    ./ghostty.nix
    ./neovim
    ./options.nix
    ./recording-sign.nix
    ./starship.nix
    ./ssh.nix
    ./tools.nix
    ./thumbnailers.nix
    # ./warp.nix
    ./xdg.nix
  ];

  programs = {
    home-manager.enable = true;
    mpv.enable = true;
    nix-index.enable = true;
    zoxide.enable = true;
  };

  services = {
    keybase.enable = true;
    # flameshot.enable = true; # Requires grim!
  };

  gtk = {
    enable = true;

    cursorTheme = {
      inherit (config.stylix.cursor) package name;
    };

    gtk3.extraConfig.gtk-application-prefer-dark-theme = 1;
    gtk4.extraConfig = {
      gtk-application-prefer-dark-theme = 1;
      gtk-cursor-theme-name = config.stylix.cursor.name;
    };
  };

  home = {
    username = "dzervas";
    homeDirectory = "/home/dzervas";
    pointerCursor = {
      inherit (config.stylix.cursor) name size;
      enable = true;
      gtk.enable = true;
      x11.enable = true;
      x11.defaultCursor = config.stylix.cursor.name;
    };
    packages = with pkgs; [
      man-pages

      # TODO: cameractrls nix defined presets
      cameractrls-gtk4
      brightnessctl
      playerctl
      rclone

      kooha # Screen recording

      gtk3 gtk4 # Install to fix some inconsistencies (cursor, DPI, theme, etc.)
      gvfs

      trilium-desktop

      (lib.mkIf config.setup.isLaptop powertop)
      (lib.mkIf (!config.setup.isLaptop) bambu-studio)
      (lib.mkIf (!config.setup.isLaptop) plasticity)
    ];

    file = {
      "${config.xdg.configHome}/katerc".source = ./katerc;
      "${config.xdg.configHome}/nixpkgs/config.nix".text = "{ allowUnfree = true; }";
    };
  };

  stylix = {
    enable = true;
    autoEnable = true;
    iconTheme = {
      enable = true;
      package = pkgs.rose-pine-icon-theme;
      light = "rose-pine-dawn";
      dark = "rose-pine";
    };
  };
}
