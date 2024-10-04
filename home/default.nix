{ config, pkgs, ... }: {
  imports = [
    ./1password.nix
    ./alacritty.nix
    ./dev.nix
    ./direnv.nix
    ./easyeffects
    ./firefox.nix
    ./fish.nix
    ./flatpak.nix
    ./gammastep.nix
    ./git.nix
    ./neovim.nix
    ./options.nix
    ./qutebrowser
    ./ssh.nix
    ./tools.nix
    ./thumbnailers.nix
    ./wine
    ./desktop/sway.nix
    ../modules/bwrapper.nix
  ];

  programs.mpv.enable = true;
  programs.home-manager.enable = true;

  bwrapper.prismlauncher = {
    # customCommand = "${pkgs.prismlauncher}/bin/prismlauncher";
    dev = "/dev";
    proc = "/proc";
    dev-bind = [ { src = "/dev/dri"; dest = "/dev/dri"; } ];

    ro-bind = [
      { src = "/etc"; dest = "/etc"; }
      { src = "/nix"; dest = "/nix"; }
      { src = "/tmp/.X11-unix"; dest = "/tmp/.X11-unix"; }
      { src = "/tmp/.ICE-unix"; dest = "/tmp/.ICE-unix"; }
      { src = "/run/opengl-driver"; dest = "/run/opengl-driver"; }
      # --ro-bind-try "$XDG_RUNTIME_DIR/pulse" /tmp/pulse \
      # --ro-bind-try "$XDG_RUNTIME_DIR/pipewire-0" /tmp/pipewire-0 \
    ];
    bind = [
      { src = "${config.home.homeDirectory}/.local/share/PrismLauncher"; dest = "${config.home.homeDirectory}/.local/share/PrismLauncher"; }
    ];
    tmpfs = [ "/tmp" ];

    unshare-all = true;
    share-net = true;
    die-with-parent = true;
  };

  home = {
    username = "dzervas";
    homeDirectory = "/home/dzervas";
    packages = with pkgs; [
      kdePackages.filelight
      kdePackages.kate
      kicad
      orca-slicer
      vorta

      bubblewrap
    ];
    file.".config/katerc".source = ./katerc;
  };
}
