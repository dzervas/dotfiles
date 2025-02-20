{ config, pkgs, ... }: {
  imports = [
    ./1password.nix
    ./alacritty.nix
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
    ./neovim.nix
    ./options.nix
    ./qutebrowser
    ./ssh.nix
    ./tools.nix
    ./thumbnailers.nix
    ./wine

    ../modules/bwrapper.nix
  ];

  programs = {
    mpv.enable = true;
    home-manager.enable = true;
  };

  services = {
    keybase.enable = true;
    kdeconnect = {
      enable = true;
      indicator = true;
    };
  };

  home = {
    username = "dzervas";
    homeDirectory = "/home/dzervas";
    packages = with pkgs; [
      kdePackages.filelight
      kdePackages.kate
      # kicad
      orca-slicer libdecor

      # TODO: cameractrls nix defined presets
      cameractrls-gtk4

      filezilla

      brightnessctl
      playerctl

      kooha # Screen recording

      rquickshare # Android file sharing
    ];
    file = {
      "${config.xdg.configHome}/katerc".source = ./katerc;
      "${config.xdg.configHome}/nixpkgs/config.nix".text = "{ allowUnfree = true; }";
      "${config.xdg.dataHome}/dev.mandre.rquickshare/.settings.json".text = builtins.toJSON {
        download_path = "${config.xdg.userDirs.download}/Shared";
        visibility = 0;
        realclose = false;
        autostart = true;
        startminimized = true;
        port = 24343;
      };
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
  };
}
