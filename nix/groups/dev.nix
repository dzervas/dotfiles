{ pkgs, ... }:

{
  environment.systemPackages = with pkgs; [
    visual-studio-code
    rustup
    golang
    nvm
    pnpm
    python3
    ipython
    pipenv
  ];
}
