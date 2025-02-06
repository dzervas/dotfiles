{ config, pkgs, ... }: {
  imports = [
    ./1password.nix
    ./alacritty.nix
    ./atuin.nix
    ./dev.nix
    ./direnv.nix
    ./easyeffects
    ./firefox.nix
    ./firmware.nix
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
    # ./desktop/sway.nix
    ./desktop/cosmic.nix

    ../modules/bwrapper.nix
  ];

  programs = {
    mpv.enable = true;
    home-manager.enable = true;
  };

  services.keybase.enable = true;

  home = {
    username = "dzervas";
    homeDirectory = "/home/dzervas";
    packages = with pkgs; [
      kdePackages.filelight
      kdePackages.kate
      # kicad
      orca-slicer libdecor
      vorta

      # TODO: cameractrls nix defined presets
      cameractrls-gtk4

      filezilla
    ];
    file = {
      ".config/katerc".source = ./katerc;
      # From: https://wiki.archlinux.org/title/Chromium#Vulkan
      ".config/chromium-flags.conf".text = ''
--enable-features=VaapiVideoDecoder,VaapiIgnoreDriverChecks,Vulkan,DefaultANGLEVulkan,VulkanFromANGLE
--enable-features=WaylandWindowDecorations
--ozone-platform=wayland
'';
      # From: https://wiki.archlinux.org/title/Wayland#Electron
      ".config/electron-flags.conf".text = ''
--enable-features=WebRTCPipeWireCapturer
--enable-features=VaapiVideoDecoder,VaapiIgnoreDriverChecks,Vulkan,DefaultANGLEVulkan,VulkanFromANGLE
--enable-features=WaylandWindowDecorations
--ozone-platform=wayland
'';
      ".config/nixpkgs/config.nix".text = "{ allowUnfree = true; }";
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
}
