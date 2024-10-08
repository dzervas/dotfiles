{ config, inputs, pkgs, ... }: let
  pkgs-overlay = import inputs.nixpkgs {
    inherit (pkgs) system;
    overlays = [
      (import ../modules/bwrapper.nix {
        bwrapperConfig = {
        prismlauncher = {
          # customCommand = "${pkgs.prismlauncher}/bin/prismlauncher";
          dev = "/dev";
          proc = "/proc";
          dev-bind = [ { src = "/dev/dri"; dest = "/dev/dri"; } ];

          setenv = {"XDG_RUNTIME_DIR" = "/tmp"; };
          unsetenv = [ "DBUS_SESSION_BUS_ADDRESS" ];

          ro-bind = [
            { src = "/etc"; dest = "/etc"; }
            { src = "/nix"; dest = "/nix"; }
            { src = "/tmp/.X11-unix"; dest = "/tmp/.X11-unix"; }
            { src = "/tmp/.ICE-unix"; dest = "/tmp/.ICE-unix"; }
            { src = "/run/opengl-driver"; dest = "/run/opengl-driver"; }

            { src = "/sys/class"; dest = "/sys/class"; try = true; }
            { src = "/sys/dev/char"; dest = "/sys/dev/char"; try = true; }
            { src = "/sys/devices/pci0000:00"; dest = "/sys/devices/pci0000:00"; try = true; }
            { src = "/sys/devices/system/cpu"; dest = "/sys/devices/system/cpu"; try = true; }

            { src = "\\$XDG_RUNTIME_DIR/pulse"; dest = "/tmp/pulse"; try = true; }
            { src = "\\$XDG_RUNTIME_DIR/pipewire-0"; dest = "/tmp/pipewire-0"; try = true; }
          ];
          bind = [
            { src = "${config.xdg.dataHome}/PrismLauncher"; dest = "${config.xdg.dataHome}/PrismLauncher"; }
          ];
          tmpfs = [ "/tmp" ];

          unshare-all = true;
          share-net = true;
          die-with-parent = true;
        };
};
      })
    ];
  };
in {
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
  ];


  programs.mpv.enable = true;
  programs.home-manager.enable = true;

  home = {
    username = "dzervas";
    homeDirectory = "/home/dzervas";
    packages = with pkgs-overlay; [
      kdePackages.filelight
      kdePackages.kate
      kicad
      orca-slicer
      vorta

      bubblewrap
      prismlauncher
    ];
    file.".config/katerc".source = ./katerc;
  };
}
