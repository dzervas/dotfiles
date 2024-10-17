{ inputs, pkgs, ... }: let
  pkgs-master = import inputs.nixpkgs-master {
    inherit (pkgs) system;
    config.allowUnfree = true;
  };
in {
  programs.poetry.enable = true;
  home.packages = with pkgs; [
    nixpkgs-fmt # Used by the Nix IDE extension
    nil # Nix language server

    # Languages
    gcc
    pkg-config
    openssl.dev

    go

    pipenv
    (python3.withPackages (p: with p; [
      ipython
      requests
      pyserial

      # Ansible deps
      ansible-core
      netaddr
      dnspython

      pip # BinaryNinja needs this
    ]))
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
    kubernetes-helm
    oci-cli
    terraform
  ] ++ [
    pkgs-master.vscode
  ];
}
