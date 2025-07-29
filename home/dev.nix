{ pkgs, ... }: {
  programs = {
    awscli.enable = true;
    poetry.enable = true;
    kubecolor = {
      enable = true;
      enableAlias = true;
    };
  };

  home.packages = with pkgs; [
    go

    # Nix
    nixpkgs-fmt # Used by the Nix IDE extension
    nix-du
    nil # Nix language server
    gnuplot

    # C/C++
    gcc
    pkg-config
    openssl.dev
    sqlite-interactive

    # Python
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
    uv

    # Rust
    cargo-edit
    cargo-expand
    rustup
    probe-rs-tools
    watchexec

    # JS
    pnpm
    nodejs

    # Cloud stuff
    krew
    kubectl
    kubectl-doctor
    kubectl-view-secret
    kubectx
    kubescape
    (wrapHelm kubernetes-helm {
      plugins = with pkgs.kubernetes-helmPlugins; [ helm-git ];
    })
    oci-cli
    terraform

    # opennoodl
  ];

  home.sessionPath = [ "$HOME/.krew/bin" ];
}
