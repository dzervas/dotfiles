{ config, inputs, lib, pkgs, ... }: {
  home = {
    packages = with pkgs; [
      lmstudio
      bubblewrap # for codex

      openspec
      snyk
      codegraph

      beads

      # opencode-desktop
    ];

    sessionVariables = {
      OPENSPEC_TELEMETRY = 0;
      BEADS_DOLT_SERVER_TLS = 1;
      GCX_KEYCHAIN = "off"; # sand's bwrap breaks it
    };
  };

  programs = {
    mcp = {
      enable = true;
      servers = {
        vresto.url = "https://mcp.vpn.dzerv.art/vresto";
        context7.url = "https://mcp.context7.com/mcp/oauth";
        mcp-gateway = {
          url = "http://127.0.0.1:8811/mcp";
          # OpenCode's config substitution; pi reads its own mcp.json
          headers.Authorization = "{file:~/.cache/pi-mcp-gateway/authorization}";
        };
      };
    };

    # Grok Build's custom sandbox profiles only extend built-in access grants,
    # so they cannot match Codex's restricted filesystem allowlist through config alone.
    # They force access to /run, /var and other dirs
    codex = {
      enable = true;
      package = pkgs.codex-latest;
    };

    opencode = {
      # enable = true;
      package = pkgs.opencode;
      enableMcpIntegration = true;
      context = ../pi/global_agents.md;
      skills = {
        # The same selection as Pi's git:github.com/mattpocock/skills@v1.3.1 package
        matt = pkgs.runCommandLocal "mattpocock-skills" {} ''
          mkdir $out
          for skill in ${inputs.mattpocock-skills}/skills/{engineering,productivity}/*/; do
            # grilling is replaced by the local forks
            [[ $(basename $skill) == grilling ]] || cp -r $skill $out/
          done
        '';
        # OpenCode's grilling fork asks with the question tool; Pi's uses questionnaire.
        opencode = ../opencode/skills;
        pi = builtins.path {
          name = "pi-skills";
          path = ../pi/skills;
          filter = path: _: baseNameOf path != "grilling";
        };
      };

      settings = {
        model = "cliproxyapi-anthropic/claude-opus-5-5";
        snapshots = false;
        warming = true; # Keep cache warm for 30', https://opencode.ai/v2/docs/warming/
        worktree.directory = ".pi/worktrees";
        websearch = false; # Use vresto
        instructions = [
          "CONTRIBUTING.md"
          "AGENTS.local.md"
        ];
        # Loaded from the repo so their relative imports reach Pi's extension code.
        plugins = map (name: "${config.home.homeDirectory}/Lab/dotfiles/opencode/plugins/${name}") [
          "memory"
          "beads"
          "jj"
          "bad"
          "cache-watch"
        ];
        # Applies to the read tool only; shell commands can still read .envrc.
        policies = [
          { action = "tool.use"; resource = "read:*.envrc"; effect = "deny"; }
        ];

        formatter.compact-nix = {
          command = [
            "compact-nix"
            "$FILE"
          ];
          extensions = [ ".nix" ];
        };

        experimental = {
          todo = true;
          subagent_depth = 2;
        };

        # One CLIProxyAPI provider per family: `canonical` makes each model inherit
        # its models.dev definition (limits, reasoning, modalities) and native SDK,
        # so Claude uses Anthropic Messages and GPT the Responses API, as in Pi.
        # Model keys must match the models.dev IDs.
        providers = let
          cliproxyapi = name: canonical: models: {
            inherit name canonical models;
            settings.baseURL = "https://ai.vpn.dzerv.art/v1";
          };
        in {
          cliproxyapi-anthropic = cliproxyapi "CLIProxyAPI Anthropic" "anthropic" {
            "claude-opus-5-5".name = "Opus 5.5";
            "claude-fable-5-1".name = "Fable 5.1";
          };
          cliproxyapi-openai = cliproxyapi "CLIProxyAPI OpenAI" "openai" {
            "gpt-6.1-sol".name = "Sol 6.1";
            "gpt-6-astra".name = "Astra 6";
          };
        };
      };
    };
  };

  services.voxtype = rec {
    enable = true;
    package = pkgs.voxtype-onnx;
    loadModels = [ settings.parakeet.model ];
    settings = {
      engine = "parakeet";
      osd.frontend = "quickshell";
      text.spoken_punctuation = true;
      audio.max_duration_secs = 600;

      hotkey = {
        enabled = false;
        mode = "toggle";
      };

      parakeet = {
        model = "parakeet-unified-en-0.6b";
        # model = "parakeet-tdt-0.6b-v3";
        # on_demand_loading = true;

        streaming = true;
        streaming_chunk_secs = 0.56;
        streaming_left_context_secs = 5.6;
        streaming_right_context_secs = 0.56;
      };

      # audio.duck_media = true;
      # audio.feedback.theme = "subtle";
    };

    # needs quickshell
    environment.PATH = lib.makeBinPath [
      pkgs.coreutils
      pkgs.which
      pkgs.quickshell
      pkgs.voxtype-onnx
    ];
  };

  xdg.configFile."bd/config.yaml".source = (pkgs.formats.yaml {}).generate "bd-config.yaml" {
    metrics.disabled = true;
    no-git-ops = true;
    # dolt = {
    #   mode = "server";
    #   host = "dolt.vpn.dzerv.art";
    #   port = 3306;
    #   user = "beads";
    #   # shared-server = true;
    # };
  };

  xdg.dataFile."voxtype/quickshell".source = "${pkgs.voxtype-onnx.src}/quickshell";
}
# `qwen3` is a local Qwen3.8 27B model. It is always free and fast, so prefer it liberally for simple
# delegated work such as reconnaissance, searching, summaries, mechanical inspection, and other low-risk tasks.
# Escalate when the task requires stronger reasoning or when its output is insufficient.
