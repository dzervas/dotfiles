{ pkgs, ... }: {
  programs = {
    poetry.enable = true;
    pyenv.enable = true;
    uv.enable = true;
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
    # Still doesn't work! No languages detected!
    (
      (
        tree-sitter.overrideAttrs (_: let
          grammars = tree-sitter.withPlugins (_: tree-sitter.allGrammars);
        in { postPatch = "ln -s ${grammars} parser"; }
        )
      ).override { webUISupport = true; }
    )

    go

    # C/C++
    pkg-config
    openssl
    sqlite-interactive

    # Python
    (python3.withPackages (p: with p; [
      requests
      pyserial
      frida-python

      lmstudio-python
      openai-agents

      # pip magic # BinaryNinja needs these
      # mcp # AI
    ]))

    # Rust
    cargo-edit
    cargo-expand
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
  ];


  home = {
    sessionPath = [ "$HOME/.krew/bin" ];
    file.".yarnrc.yaml".text = ''
      enableScripts = false;
      enableTelemetry = 0;
      npmMinimalAgeGate = 60 * 24 * 7; # 1 week in minutes
    '';
  };
}
