{ pkgs, flake-inputs, ... }: {
  imports = [
    ./1password.nix
    ./alacritty.nix
    ./burp.nix
    ./dev.nix
    ./firefox.nix
    ./fish.nix
    ./flatpak.nix
    ./git.nix
    ./neovim.nix
    ./options.nix
    ./ssh.nix
    ./tools.nix
    ./desktop/sway.nix

    flake-inputs.nix-flatpak.homeManagerModules.nix-flatpak
  ];

  # CLI tools
  programs.direnv.enable = true;

  programs.home-manager.enable = true;
  home = {
    username = "dzervas";
    homeDirectory = "/home/dzervas";
    packages = with pkgs; [
      kdePackages.filelight
    ];
  };
}
