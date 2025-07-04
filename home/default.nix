{ config, isPrivate, pkgs, ... }: {
  imports = [
    ./1password.nix
    # ./alacritty.nix
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
    ./neovim.nix
    ./options.nix
    ./qutebrowser
    ./recording-sign.nix
    ./starship.nix
    ./ssh.nix
    ./tools.nix
    ./thumbnailers.nix
    ./wine
    ./xdg.nix

    ../modules/bwrapper.nix
  ];

  programs = {
    mpv.enable = true;
    home-manager.enable = true;
    zoxide.enable = true;

    nh = {
      enable = true;
      flake = "${config.home.homeDirectory}/Lab/dotfiles";
      clean.enable = true;
    };
  };

  services = {
    keybase.enable = true;
    kdeconnect = {
      enable = true;
      indicator = true;
    };
    # flameshot.enable = true; # Requires grim!
  };

  gtk = {
    enable = true;

    cursorTheme = {
      inherit (config.stylix.cursor) package name;
    };

    gtk3.extraConfig = { gtk-application-prefer-dark-theme = 1; };

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
      # home-manager

      kdePackages.filelight
      kdePackages.kate
      # kicad
      krita
      inkscape-with-extensions
      orca-slicer libdecor

      itch

      # TODO: cameractrls nix defined presets
      cameractrls-gtk4

      filezilla

      brightnessctl
      playerctl

      kooha # Screen recording

      gtk3 gtk4 # Install to fix some inconsistencies (cursor, DPI, theme, etc.)

      gvfs
      (lib.mkIf isPrivate pico8)
      (lib.mkIf isPrivate atuin-desktop)
      (lib.mkIf isPrivate burpsuite)

      (lib.mkIf config.setup.isLaptop powertop)
    ];
    file = {
      "${config.xdg.configHome}/katerc".source = ./katerc;
      "${config.xdg.configHome}/nixpkgs/config.nix".text = "{ allowUnfree = true; }";
    };
  };

  bwrapper.prismlauncher = {
    dev-bind = [ { src = "/dev/dri"; } ];

    setenv = { "XDG_RUNTIME_DIR" = "/tmp"; };
    unsetenv = [ "DBUS_SESSION_BUS_ADDRESS" ];

    ro-bind = [
      { src = "/etc"; }
      { src = "/nix"; }
      { src = "/tmp/.X11-unix"; }
      { src = "/tmp/.ICE-unix"; try = true; }
      { src = "/run/opengl-driver"; }

      { src = "/sys/class"; try = true; }
      { src = "/sys/dev/char"; try = true; }
      { src = "/sys/devices/pci0000:00"; try = true; }
      { src = "/sys/devices/system/cpu"; try = true; }

      { src = "\\$XDG_RUNTIME_DIR/pulse"; dest = "/tmp/pulse"; try = true; }
      { src = "\\$XDG_RUNTIME_DIR/pipewire-0"; dest = "/tmp/pipewire-0"; try = true; }
    ];
    bind = [ { src = "${config.xdg.dataHome}/PrismLauncher"; } ];
    tmpfs = [ "/tmp" ];

    unshare-all = true;
    share-net = true;
    die-with-parent = true;
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
