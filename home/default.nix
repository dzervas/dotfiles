{ pkgs, ... }: {
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
    packages = with pkgs; [
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
