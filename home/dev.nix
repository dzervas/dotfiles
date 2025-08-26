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

    claude-code = {
      enable = true;
      mcpServers = {
        binaryninja = {
          command = "python";
          args = [
            "/home/dzervas/.binaryninja/repositories/community/plugins/fosdickio_binary_ninja_mcp/bridge/binja_mcp_bridge.py"
          ];
          env = {};
        };
        grafana = {
          command = "op";
          args = [
            "run" "--"
            "podman" "run"
            "--rm" "-i"
            "-e" "GRAFANA_URL"
            "-e" "GRAFANA_API_KEY"
            "mcp/grafana"
            "-t" "stdio"
          ];
          env = {
            GRAFANA_URL = "op://Sites/Grafana/website";
            GRAFANA_API_KEY = "op://Sites/Grafana/api-key";
          };
        };
        n8n = {
          command = "op";
          args = [
            "run" "--"
            "podman" "run"
            "--rm" "-i" "--init"
            "-e" "MCP_MODE=stdio"
            "-e" "LOG_LEVEL=error"
            "-e" "DISABLE_CONSOLE_OUTPUT=true"
            "-e" "N8N_API_URL"
            "-e" "N8N_API_KEY"
            "ghcr.io/czlonkowski/n8n-mcp:latest"
          ];
          env = {
            N8N_API_URL = "op://Sites/N8n/website";
            N8N_API_KEY = "op://Sites/N8n/api-key";
          };
        };
      };
    };
  };

  home.packages = with pkgs; [
    cursor-cli
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

      pip magic # BinaryNinja needs these
      mcp # AI
    ]))
    uv

    # Rust
    cargo-edit
    cargo-expand
    rustup
    probe-rs-tools
    watchexec
    strace

    # JS
    pnpm
    nodejs
    yarn-berry

    # Cloud stuff
    argocd
    krew
    kubectl
    kubectl-doctor
    kubectx
    kubescape
    (wrapHelm kubernetes-helm {
      plugins = with pkgs.kubernetes-helmPlugins; [ helm-git ];
    })
    oci-cli
    terraform

    foundry
  ];

  home.sessionPath = [ "$HOME/.krew/bin" ];
}
