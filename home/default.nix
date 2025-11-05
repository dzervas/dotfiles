{ config, lib, pkgs, ... }: {
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
    ./updater
    ./xdg.nix
  ];

  programs = {
    home-manager.enable = true;
    mpv.enable = true;
    nix-index.enable = true;
    zoxide.enable = true;
    # TODO: Split to its own module and add config & keymaps
    zed-editor = {
      enable = true;
      # https://github.com/modelcontextprotocol/servers/tree/main/src/sequentialthinking
      extensions = [
        "vscode-dark-modern" # Theme

        # Language support
        "astro"
        "basher"
        "comment" # Highlights TODO/FIXME/etc.
        "dockerfile"
        "fish"
        "html"
        "jsonnet"
        "nix"
        "svelte"
        "toml"
        "tombi" # Toml LSP
        "tree-sitter-query"

        # Snippets
        "html-snippets"
        "javascript-snippets"
        "python-snippets"
        "rust-snippets"
        "svelte-snippets"
        "typescript-snippets"

        "probe-rs"

        # MCP
        "mcp-server-sequential-thinking"
        "mcp-server-github"
        "svelte-mcp"
      ];
      extraPackages = with pkgs; [
        nil
        nixd
      ];
    };
  };

  stylix.targets.zed.enable = false;

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

      brightnessctl
      playerctl
      rclone

      kooha # Screen recording

      gtk3 gtk4 # Install to fix some inconsistencies (cursor, DPI, theme, etc.)
      gvfs

      trilium-desktop

      nix-update

      (tree-sitter.withPlugins (p: builtins.attrValues p))

      (lib.mkIf config.setup.isLaptop powertop)
      (lib.mkIf (!config.setup.isLaptop) plasticity)

      cameractrls-gtk4
      lmstudio
    ];

    file = {
      "${config.xdg.configHome}/katerc".source = ./katerc;
      "${config.xdg.configHome}/nixpkgs/config.nix".text = "{ allowUnfree = true; }";
    };
  };

  # Disable gnome-keyring's ssh component to avoid conflicts with ssh-agent
  services.gnome-keyring.components = [ "secrets" ];

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
