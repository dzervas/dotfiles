{ config, lib, pkgs, ... }: {
  imports = [
    ./1password.nix
    ./ai.nix
    ./pi-mcp-gateway.nix
    ./atuin.nix
    ./brave.nix
    ./dev.nix
    ./direnv.nix
    ./docker-secrets-engine.nix
    ./easyeffects
    # ./firefox.nix
    ./firmware.nix
    ./fish.nix
    ./flatpak.nix
    ./git.nix
    ./ghostty.nix
    ./neovim
    ./options.nix
    ./pi.nix
    ./recording-sign.nix
    ./starship.nix
    ./ssh.nix
    ./tools.nix
    # ./thumbnailers.nix
    ./updater
    ./xdg.nix
    ./zellij.nix
  ];

  programs = {
    home-manager.enable = true;
    mullvad-vpn.enable = true;
    nix-index.enable = true;
    satty.enable = true;
    zoxide.enable = true;
    zed-editor.enable = true;
    # mpv.enable = true;

    #   npm = {
    #     enable = true;
    #     settings = {
    #       min-release-age = 7;
    #       omit = [ "dev" "optional" "peer" ];
    #       prefer-dedupe = true;
    #       prefer-offline = true;
    #       strict-peer-deps = true;
    #       install-strategy = "linked";
    #     };
    #   };
  };

  xdg.configFile."nixpkgs/config.nix".text = "{ allowUnfree = true; }";

  systemd.user.tmpfiles.rules = [
    "L ${config.xdg.configHome}/zed/settings.json - - - - ${config.home.homeDirectory}/Lab/dotfiles/home/zed/settings.json"
    "L ${config.xdg.configHome}/zed/keymap.json - - - - ${config.home.homeDirectory}/Lab/dotfiles/home/zed/keymap.json"
  ];

  gtk = {
    enable = true;

    cursorTheme = { inherit (config.stylix.cursor) package name; };

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

      brightnessctl
      playerctl
      rclone

      kooha # Screen recording

      gtk3
      gtk4 # Install to fix some inconsistencies (cursor, DPI, theme, etc.)
      gvfs

      nix-update
      nil
      nixd

      # (tree-sitter.withPlugins (p: builtins.attrValues p))

      (lib.mkIf config.setup.isLaptop powertop)

      cameractrls-gtk4
      anytype-cli
      zenity
    ];

    sessionVariables.TERMINAL = config.setup.terminal;
  };

  services = {
    kdeconnect.enable = true;
    keybase.enable = true;

    # Disable gnome-keyring's ssh component to avoid conflicts with ssh-agent
    gnome-keyring.components = [ "secrets" ];
  };

  stylix = {
    enable = true;
    autoEnable = true;
    icons = {
      enable = true;
      package = pkgs.rose-pine-icon-theme;
      light = "rose-pine-dawn";
      dark = "rose-pine";
    };

    targets.zed.enable = false;
    # Stylix sets the deprecated programs.rofi.font, even when rofi is disabled.
    # The font is set in desktop/home/components/rofi.nix instead
    targets.rofi.fonts.enable = false;
  };

  # Enable the mid-click paste to gsettings-based apps (e.g. ghostty)
  dconf.settings."org/gnome/desktop/interface".gtk-enable-primary-paste = true;
}
