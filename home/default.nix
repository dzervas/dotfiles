{ pkgs, ... }: {
  imports = [
    ./1password.nix
    ./alacritty.nix
    ./dev.nix
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
    ./desktop/sway.nix
  ];

  programs.direnv.enable = true;
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
    ];
    file.".config/katerc".source = ./katerc;
  };
}
