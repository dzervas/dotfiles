{ pkgs, specialArgs, ... }: {
  imports = [
    ./1password.nix
    ./alacritty.nix
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

    specialArgs.inputs.nix-flatpak.homeManagerModules.nix-flatpak
    (if specialArgs.isPrivate or false then
      builtins.trace "Private submodule build" ./private
    else
      {})
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
