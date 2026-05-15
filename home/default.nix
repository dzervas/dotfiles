{
  config,
  inputs,
  lib,
  pkgs,
  ...
}:
{
  imports = [
    ./1password.nix
    ./ai.nix
    ./atuin.nix
    ./brave.nix
    ./dev.nix
    ./direnv.nix
    ./easyeffects
    # ./firefox.nix
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
    # ./thumbnailers.nix
    ./updater
    ./xdg.nix
    ./zellij.nix
  ];

  programs = {
    home-manager.enable = true;
    # mpv.enable = true;
    mullvad-vpn.enable = true;
    nix-index.enable = true;
    satty.enable = true;
    zoxide.enable = true;
    zed-editor = {
      enable = true;
      # package = inputs.nixpkgs-master.legacyPackages.x86_64-linux.zed-editor;
    };

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

  xdg.configFile = {
    "nixpkgs/config.nix".text = "{ allowUnfree = true; }";
    katerc.source = ./katerc;
  };

  systemd.user.tmpfiles.rules = [
    "L ${config.xdg.configHome}/zed/settings.json - - - - ${config.home.homeDirectory}/Lab/dotfiles/home/zed/settings.json"
    "L ${config.xdg.configHome}/zed/keymap.json - - - - ${config.home.homeDirectory}/Lab/dotfiles/home/zed/keymap.json"
  ];

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
      (lib.mkIf (!config.setup.isLaptop) plasticity)

      cameractrls-gtk4
      # voxtype
      # n8n-cli
      # playwright-cli

      anytype-cli
      freecad
      inputs.mcp-firewall.packages.x86_64-linux.default

      ladybird
    ];

    sessionVariables.TERMINAL = config.setup.terminal;
  };

  services = {
    kdeconnect.enable = true;
    keybase.enable = true;
    # flameshot.enable = true;

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
  };
}

# ZMK building
# p run -it --rm -v $(pwd):/config --workdir /config zmkfirmware/zmk-build-arm:stable
# west init -l config
# west update --fetch-opt=--filter=tree:0
