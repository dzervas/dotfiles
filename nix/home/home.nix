{ pkgs, flake-inputs, ... }: {
  imports = [
    ./1password.nix
    ./alacritty.nix
    # ./private
    ./dev.nix
    ./firefox.nix
    ./fish.nix
    ./flatpak.nix
    ./git.nix
    ./neovim.nix
    ./options.nix
    ./qutebrowser.nix
    ./ssh.nix
    ./tools.nix
    ./desktop/sway.nix

    flake-inputs.nix-flatpak.homeManagerModules.nix-flatpak
    # flake-inputs.private.homeManagerModules
  ];

  # CLI tools
  programs.direnv.enable = true;

  programs.home-manager.enable = true;
  home = {
    username = "dzervas";
    homeDirectory = "/home/dzervas";
    packages = with pkgs; [
      kdePackages.filelight
      kdePackages.kate
      kicad
      vorta
    ];
    file.".config/katerc".source = ./katerc;
  };
}
