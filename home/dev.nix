{ pkgs, ... }: {
  programs = {
    awscli = {
      enable = true;
    };
    poetry.enable = true;
    kubecolor = {
      enable = true;
      enableAlias = true;
    };
  };
  home.packages = with pkgs; [
    nixpkgs-fmt # Used by the Nix IDE extension
    nil # Nix language server

    # Languages
    gcc
    pkg-config
    openssl.dev
    sqlite-interactive

    go

    pipenv
    (python3.withPackages (p: with p; [
      ipython
      requests
      pyserial
      python-dotenv
      frida-python

      # Ansible deps
      ansible-core
      netaddr
      dnspython

      pip # BinaryNinja needs this
    ]))
    pyenv

    cargo
    cargo-edit
    cargo-expand
    rustup
    probe-rs-tools
    watchexec

    pnpm
    nodejs

    # Cloud stuff
    kubectl
    kubectx
    kubescape
    kubernetes-helm
    oci-cli
    terraform
    cilium-cli

    opennoodl
  ];
}
