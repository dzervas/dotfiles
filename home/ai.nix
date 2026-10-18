{ config, lib, pkgs, ... }: let
  nodejs = pkgs.nodejs_22; # tree-sitter does not work with nodejs_24
  pi-coding-agent-package = pkgs.pi-coding-agent-latest;
  piImportNpmLock = pkgs.callPackage (pkgs.path + "/pkgs/build-support/node/import-npm-lock") {
    callPackages = pkgs.newScope { inherit nodejs; };
  };
  piExtensionNodeModules = piImportNpmLock.buildNodeModules {
    inherit nodejs;
    npmRoot = ../pi/extensions;

    derivationArgs = {
      npmFlags = [ "--legacy-peer-deps" ];
      doCheck = true;
      checkPhase = ''
        npm audit
      '';
    };
  };
  piCodingAgentNodeModules = pkgs.runCommand "pi-coding-agent-node-modules" {} ''
    mkdir -p $out/node_modules/@earendil-works
    ln -s ${pi-coding-agent-package}/lib/node_modules/pi-monorepo \
      $out/node_modules/@earendil-works/pi-coding-agent
  '';
  piCodingAgent = pkgs.symlinkJoin {
    name = "pi-coding-agent-with-extension-node-path";
    paths = [ pi-coding-agent-package ];
    nativeBuildInputs = [ pkgs.makeWrapper ];
    # Pi realpaths symlinked extensions before loading them, so bare imports
    # need to resolve from the extension dependency closure while pi runs.
    # Async subagent runners also need the Nix-installed Pi package exposed under
    # its package name for detached module resolution.
    postBuild = ''
      wrapProgram $out/bin/pi \
        --prefix NODE_PATH : ${piExtensionNodeModules}/node_modules \
        --prefix NODE_PATH : ${piCodingAgentNodeModules}/node_modules
    '';
  };

  # Contain the server as well as its agents and terminals; wrapping only `pi`
  # would leave dashboard file operations and terminals on the host.
  # Run without `start` (foreground): daemonizing or in-app restarts end sand's
  # lifetime and tear down its PID namespace, including the agent processes.
  piDashboard = pkgs.writeScriptBin "pi-dashboard" ''
    #!${pkgs.fish}/bin/fish --no-config
    function sand
      ${builtins.readFile ./fish-functions/sand.fish}
    end
    sand -c 'exec "$@"' -- -- ${lib.getExe pkgs.pi-dashboard} $argv
  '';

  piPackages = [
    "npm:pi-subagents@0.79.1"
    "npm:pi-cliproxyapi-provider@0.15.58"
    {
      source = "git:github.com/mattpocock/skills@v1.3.1";
      extensions = [];
      skills = [
        "skills/engineering/*"
        "skills/productivity/*"
        "!skills/productivity/grilling/**" # Local fork uses the questionnaire tool.
      ];
    }
  ];
  piPackagesSources = map (p: p.source or p) piPackages;
  # Nix settings share the same catalogue as the TypeScript extensions.
  piExtensionPrompt = extension: marker: let
    sections = lib.splitString "=== ext:${extension} ${marker} ===\n" (
      builtins.readFile ../pi/extensions/prompts.md
    );
  in assert builtins.length sections == 2;
  lib.trim (builtins.head (lib.splitString "\n=== ext:" (builtins.elemAt sections 1)));
  # Extend bundled roles without maintaining copies of their prompts.
  piSubagentReadTools = [
    "read"
    "grep"
    "find"
    "ls"
    "bash"
    "contact_supervisor"
    "background_jobs"
    "codemode"
    "mcp:vresto"
    "mcp:context7"
    "mcp:mcp-gateway"
    "todo"
    "memory_search"
  ];

  piExtensionBump = pkgs.writeShellApplication {
    name = "pi-extension-bump";
    runtimeInputs = with pkgs; [
      coreutils
      jq
      nodejs
      python3
      snyk
    ];

    text = ''
      set -euo pipefail

      ai_nix="''${DOTFILES_PATH:-${config.home.homeDirectory}/Lab/dotfiles}/home/ai.nix"
      specs=(${lib.escapeShellArgs piPackagesSources})
      cutoff="$(date -u -d '7 days ago' +%F)"
      original_specs=()
      resolved_specs=()

      for spec in "''${specs[@]}"; do
        case "$spec" in
          npm:*@*) ;;
          *) continue ;;
        esac

        original_specs+=("$spec")

        package_version="''${spec#npm:}"
        package="''${package_version%@*}"

        echo "Resolving $package..." >&2
        candidates="$(npm view "$package" time --json \
          | jq -r --arg cutoff "$cutoff" '
              del(.created, .modified)
              | to_entries
              | map(select(.value[0:10] <= $cutoff))
              | .[].key
            ' \
          | sort -V -r)"

        selected=""
        for candidate in $candidates; do
          echo "Checking $package@$candidate with Snyk..." >&2
          if snyk test "$package@$candidate" --severity-threshold=medium; then
            selected="$candidate"
            break
          fi
        done

        if [[ -z "$selected" ]]; then
          echo "No version of $package older than $cutoff passed Snyk" >&2
          exit 1
        fi

        echo "Selected $package@$selected" >&2
        resolved_specs+=("npm:$package@$selected")
      done

      python3 - "$ai_nix" "''${#original_specs[@]}" \
        "''${original_specs[@]}" "''${resolved_specs[@]}" <<'PY'
      import sys
      from pathlib import Path

      path = Path(sys.argv[1])
      count = int(sys.argv[2])
      original_specs = sys.argv[3:3 + count]
      resolved_specs = sys.argv[3 + count:]
      text = path.read_text()

      for original, resolved in zip(original_specs, resolved_specs, strict=True):
          needle = f'"{original}"'
          occurrences = text.count(needle)
          if occurrences != 1:
              print(f"Warning: expected 1 occurrence of {needle}, found {occurrences}")
              continue
          text = text.replace(needle, f'"{resolved}"', 1)
      path.write_text(text)
      PY
    '';
  };
in {
  home = {
    packages = with pkgs; [
      lmstudio
      bubblewrap # for codex

      openspec
      piExtensionBump
      # piDashboard
      snyk
      codegraph

      beads
    ];

    sessionVariables = {
      OPENSPEC_TELEMETRY = 0;
      PI_SKIP_VERSION_CHECK = 1;
    };
    file = {
      ".pi/agent/AGENTS.md".source =
        config.lib.file.mkOutOfStoreSymlink "${config.home.homeDirectory}/Lab/dotfiles/pi/global_agents.md";
      ".pi/agent/sandbox.ts".source =
        config.lib.file.mkOutOfStoreSymlink "${config.home.homeDirectory}/Lab/dotfiles/pi/sandbox.ts";
      ".pi/agent/extensions".source =
        config.lib.file.mkOutOfStoreSymlink "${config.home.homeDirectory}/Lab/dotfiles/pi/extensions";
      ".pi/agent/skills".source =
        config.lib.file.mkOutOfStoreSymlink "${config.home.homeDirectory}/Lab/dotfiles/pi/skills";
      ".pi/agent/themes".source =
        config.lib.file.mkOutOfStoreSymlink "${config.home.homeDirectory}/Lab/dotfiles/pi/themes";
      ".pi/agent/node_modules".source = piExtensionNodeModules + "/node_modules";
      ".codex/AGENTS.md".source =
        config.lib.file.mkOutOfStoreSymlink "${config.home.homeDirectory}/Lab/dotfiles/pi/global_agents.md";
      ".codex/skills/global".source =
        config.lib.file.mkOutOfStoreSymlink "${config.home.homeDirectory}/Lab/dotfiles/pi/skills";
    };
  };

  programs = {
    # Grok Build's custom sandbox profiles only extend built-in access grants,
    # so they cannot match Codex's restricted filesystem allowlist through config alone.
    # They force access to /run, /var and other dirs
    codex = {
      enable = true;
      package = pkgs.codex-latest;
    };
    pi-coding-agent = {
      enable = true;
      package = piCodingAgent;
      extraPackages = with pkgs; [
        nodejs
        typescript
      ];

      settings = rec {
        quietStartup = true;
        collapseChangelog = true;
        enableInstallTelemetry = false;
        showHardwareCursor = true;
        showCacheMissNotices = true;
        transport = "auto";
        tuiMode = "regular";
        outputPad = 0;
        cacheWarming = "idle";
        theme = "dark-classic"; # pre-v1 dark palette, see pi/themes/
        terminal = {
          showTerminalProgress = true;
          clearOnShrink = true;
        };
        warnings.anthropicExtraUsage = false;

        packages = piPackages;
        defaultTools = [ "+codemode" ]; # "+tool_search" results in busted cache when tools change
        npmCommand = [ "${nodejs}/bin/npm" ];

        pi-cliproxyapi-provider = {
          gpt56ContextWindow = "full"; # 1M context for GPT 5.6/6
          modelOverrides."gpt-6.1-sol".contextWindow = 1050000; # Not updated yet?
        };

        subagents = {
          defaultProvider = "cpa";
          defaultModel = "cpa/gpt-6.1-sol";
          defaultThinking = "medium";
          # Sol handles parallel execution; Opus is the independent planning/review
          # tier. These are workload defaults, not locks: per-run overrides still win.
          agentOverrides = lib.mapAttrs
            (
              _: role:
              { inheritProjectContext = true; inheritGlobalContext = true; inheritSkills = true; }
              // role
            )
            {
              scout = {
                model = "cpa/gpt-6.1-sol";
                thinking = "low";
                # Upstream scout writes context files; retain that alongside our tools.
                tools = piSubagentReadTools ++ [ "write" ];
              };
              delegate = {
                model = "cpa/gpt-6.1-sol";
                thinking = "medium";
                # Grant bounded nested delegation without copying the bundled prompt.
                allowNestedSubagents = true;
                tools = piSubagentReadTools ++ [
                  "edit"
                  "write"
                  "memory"
                ];
              };
              worker = {
                model = "cpa/claude-opus-5-5";
                thinking = "medium";
              };
              reviewer = {
                model = "cpa/claude-opus-5-5";
                thinking = "high";
              };
              oracle = {
                model = "cpa/claude-opus-5-5";
                thinking = "high";
                tools = piSubagentReadTools;
              };
              # Bundled research prompts require pi-web-access. Use our existing
              # Vresto MCP instead, without installing a second search provider.
              researcher = {
                model = "cpa/gpt-6.1-sol";
                thinking = "medium";
                tools = [
                  "read"
                  "codemode"
                  "mcp:vresto"
                  "contact_supervisor"
                ];
                systemPrompt = piExtensionPrompt "subagents" "researcher" + "\n";
              };
              evidence-auditor = {
                model = "cpa/claude-opus-5-5";
                thinking = "high";
                tools = [
                  "read"
                  "codemode"
                  "mcp:vresto"
                  "contact_supervisor"
                ];
                systemPrompt = piExtensionPrompt "subagents" "evidence-auditor" + "\n";
              };
            };
          # Foreground children do not load ambient extensions. Use the same tool
          # providers and fail-closed permission hooks in both execution modes.
          # The child's SDK loads native MCP and Code Mode itself.
          defaultExtensions =
            (map (name: "${config.home.homeDirectory}/.pi/agent/extensions/${name}") [
              "permissions.ts"
              "permission-prompt.ts"
              "protected-paths.ts"
              "background-bash.ts"
              "todo/index.ts"
              "memory/index.ts"
              "local-context.ts"
            ])
            ++ [
              "${config.home.homeDirectory}/.pi/agent/npm/node_modules/pi-cliproxyapi-provider/extensions/index.ts"
            ];
        };

        defaultModel = builtins.elemAt enabledModels 0;
        defaultProvider = "cpa";
        defaultThinkingLevel = "medium";
        enabledModels = [
          "claude-opus-5-5"
          "openai-codex/gpt-6.1-sol"
          "openai-codex/gpt-6-astra"
          "claude-fable-5-1"
          "qwen-flash-next"
        ];
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

  xdg.dataFile."voxtype/quickshell".source = "${pkgs.voxtype-onnx.src}/quickshell";
}
# `qwen3` is a local Qwen3.8 27B model. It is always free and fast, so prefer it liberally for simple
# delegated work such as reconnaissance, searching, summaries, mechanical inspection, and other low-risk tasks.
# Escalate when the task requires stronger reasoning or when its output is insufficient.
