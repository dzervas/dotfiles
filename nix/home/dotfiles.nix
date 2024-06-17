{ pkgs, ... }:

{
  environment.systemPackages = with pkgs; [
    alacritty
    bat
    colordiff
    ripgrep
    fd
    fzf
    vim
    neovim
    fish
  ];

  programs.fish.enable = true;
}
