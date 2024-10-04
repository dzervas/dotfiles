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
    (python3.withPackages (p: [
      p.ipython
      p.requests
      p.pyserial

      # Ansible deps
      p.ansible-core
      p.netaddr
      p.dnspython
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
    # ansible
  ];
}
