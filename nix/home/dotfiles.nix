{ pkgs, ... }:

{
  home.packages = with pkgs; [
    alacritty
    neovim
  ];

  programs.fish.enable = true;
}
