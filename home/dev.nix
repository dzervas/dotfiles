{ pkgs, ... }: {
  programs = {
    awscli.enable = true;
    poetry.enable = true;
    pyenv.enable = true;
    kubecolor = {
      enable = true;
      enableAlias = true;
    };

    k9s = {
      enable = true;
      plugins = {
        debug = {
          description = "Add debug container";
          shortCut = "Shift-D";
          scopes = ["all"];

          confirm = true;
          dangerous = true;
          background = false;

          command = "bash";
          args = [
            "-c"
            "kubectl --kubeconfig=$KUBECONFIG debug -it --context $CONTEXT -n=$NAMESPACE $POD --target=$NAME --image=nicolaka/netshoot:v0.13 --share-processes -- bash"
          ];
        };
        watch-events = {
          description = "Get Events";
          shortCut = "Shift-E";
          scopes = ["all"];

          confirm = false;
          background = false;

          command = "bash";
          args = [
            "-c"
            "kubectl events --context $CONTEXT --namespace $NAMESPACE --for $RESOURCE_NAME.$RESOURCE_GROUP/$NAME --watch"
          ];
        };
      };
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
    pkg-config
    openssl
    sqlite-interactive

    # Python
    # (python3.withPackages (p: with p; [
    #   ipython
    #   requests
    #   pyserial
    #   python-dotenv
    #   frida-python
    #
    #   pip magic # BinaryNinja needs these
    #   mcp # AI
    # ]))

    # Rust
    cargo-edit
    cargo-expand
    # rustup
    # probe-rs-tools
    # watchexec
    strace

    # Cloud stuff
    kubectl
    kubectx
    kubescape
    (wrapHelm kubernetes-helm {
      plugins = with pkgs.kubernetes-helmPlugins; [ helm-git ];
    })
    oci-cli
    terraform
    k2tf
    tfautomv
    hurl
    # krr

    foundry # cast eth chain testing tool
  ];

  home.sessionPath = [ "$HOME/.krew/bin" ];
}
