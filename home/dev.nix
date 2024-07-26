{ pkgs, ... }:

{
  programs.poetry.enable = true;
  home.packages = with pkgs; [
    vscode
    nixpkgs-fmt # Used by the Nix IDE extension
    nil # Nix language server

    # Languages
    gcc
    pkg-config
    openssl.dev

    go

    pipenv
    (python3Packages.python.withPackages (p: [ p.ipython ]))
    # python311Packages.ipython
    pyenv

    cargo-edit
    cargo-expand
    rustup
    probe-rs-tools

    pnpm
    nodejs

    # Cloud stuff
    kubectl
    kubectx
    oci-cli
    terraform
  ];
}
