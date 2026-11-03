{ config, lib, pkgs, ... }: let
  nodejs = pkgs.nodejs_22; # tree-sitter does not work with nodejs_24
  pi-coding-agent-package = pkgs.pi-coding-agent-latest;
  piPackages = [
    "npm:pi-subagents@0.84.0"
    "npm:pi-cliproxyapi-provider@0.16.1"
    {
      source = "git:github.com/mattpocock/skills@v1.3.2";
      extensions = [];
      skills = [
        "skills/engineering/*"
        "skills/productivity/*"
        "!skills/productivity/grilling/**" # Local fork uses the questionnaire tool.
      ];
    }
  ];

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
    inherit (pi-coding-agent-package) meta;
    paths = [ pi-coding-agent-package ];
    nativeBuildInputs = [ pkgs.makeWrapper ];
    # Pi realpaths symlinked extensions before loading them, so bare imports
    # need to resolve from the extension dependency closure while pi runs.
    # Async subagent runners also need the Nix-installed Pi package exposed under
    # its package name for detached module resolution.
    # The extra PATH entries live here rather than in programs.pi-coding-agent.extraPackages
    # so the sandboxed pis gets them too.
    postBuild = ''
      wrapProgram $out/bin/pi \
        --prefix NODE_PATH : ${piExtensionNodeModules}/node_modules \
        --prefix NODE_PATH : ${piCodingAgentNodeModules}/node_modules \
        --suffix PATH : ${
          lib.makeBinPath (
            with pkgs;
            [
              nodejs
              typescript
            ]
          )
        }
    '';
  };

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
    # "mcp:mcp-gateway"
    "todo"
    "memory_search"
  ];

  # Same containment as sand (home/fish-functions/sand.fish), which still backs
  # pifleet and the opencode server.
  # Native MCP OAuth state stays writable in the persistent sandbox home. Host keyrings
  # and Docker sockets stay outside, and the agent gets only its own atuin memory
  # profile - never the shell-history store or its key.
  piSandbox = pkgs.mkNixPak {
    config = { sloth, ... }: {
      app.package = piCodingAgent;
      dbus.enable = false;
      gpu.enable = true;

      bubblewrap = {
        network = true;
        dieWithParent = true;
        tmpfs = [ "/tmp" ];

        bind = {
          # $PIS_* come from the pis wrapper below
          rw = [
            [
              "$PIS_HOME"
              "$HOME"
            ]
            "$PIS_PROJECT"
            "$HOME/.pi/agent/sessions"
            "$HOME/.local/share/atuin-agent"
            "$HOME/.pi/agent/auth.json"
            "$HOME/.pi/agent/mcp.json"
            "$HOME/.pi/agent/mcp-auth.json"
            "$HOME/.pi/dashboard"
            "$HOME/.pi/agent/run-history.jsonl"
            "$HOME/.config/gcx"
            "$HOME/.config/.wrangler/config/agents.toml"
          ];
          # After NixPak's own /etc/resolv.conf bind, so the copy wins
          ro = lib.mkAfter [
            [
              "$PIS_ETC/resolv.conf"
              "/etc/resolv.conf"
            ]
            [
              "$PIS_ETC/passwd"
              "/etc/passwd"
            ]
            [
              "$PIS_ETC/group"
              "/etc/group"
            ]
            "/etc/static"
            "/etc/nix"
            "/etc/ssl"
            "/etc/nsswitch.conf"
            "/etc/protocols"
            "/etc/services"
            "/run/current-system/sw"
            (sloth.concat' "/etc/profiles/per-user/" (sloth.env "USER"))
            "/run/binfmt"
            "/bin"
            "/usr/bin"
            "/lib"
            "/lib64"

            "$HOME/.pi/agent/settings.json"
            "$HOME/.pi/agent/models.json"
            "$HOME/.pi/agent/node_modules"
            "$HOME/.pi/agent/npm"
            "$HOME/.pi/agent/extensions"
            "$HOME/.pi/agent/skills"
            "$HOME/.pi/agent/themes"
            "$HOME/.pi/agent/pi-cliproxyapi-provider"
            "$HOME/.pi/agent/AGENTS.md"
            "$HOME/.pi/agent/sandbox.ts"
            "$HOME/.cache/pi-mcp-gateway/authorization"
            "$HOME/.config/atuin-agent"
            "$HOME/.config/jj"
            "$HOME/.config/git"
            "$HOME/.config/gh-agent"
            "$HOME/.config/fish"
          ];
          # gpu.enable covers /dev/dri only
          dev = [
            "/dev/nvidiactl"
            "/dev/nvidia0"
            "/dev/nvidia-uvm"
            "/dev/nvidia-modeset"
          ];
        };

        env = {
          CI = "1";
          GH_CONFIG_DIR = sloth.concat' sloth.homeDir "/.config/gh-agent";
          ATUIN_CONFIG_DIR = sloth.concat' sloth.homeDir "/.config/atuin-agent";
          ATUIN_DATA_DIR = sloth.concat' sloth.homeDir "/.local/share/atuin-agent";
        };
      };
    };
  };

  # Computes what NixPak can't: one persistent home per project, the secrets to drop
  # and copies of files that the sandbox must not see replaced.
  pis = pkgs.writeShellApplication {
    name = "pis";
    text = ''
      project_dir="$PWD"
      PIS_PROJECT="$project_dir"
      if [[ "$project_dir" == "$HOME"/Lab/work/* ]]; then
        PIS_PROJECT="$HOME/Lab/work"
      fi
      sandbox_dir="$HOME/.cache/pi/sandboxes/$(printf '%s' "$project_dir" | ${pkgs.coreutils}/bin/sha256sum | ${pkgs.coreutils}/bin/cut -d' ' -f1)"
      PIS_HOME="$sandbox_dir/home"
      PIS_ETC="$sandbox_dir/etc"

      if [[ "$project_dir" == "$HOME"/* ]]; then
        project_parent="$(${pkgs.coreutils}/bin/dirname "$PIS_PROJECT")"
        ${pkgs.coreutils}/bin/mkdir -p "$PIS_HOME/''${project_parent#"$HOME"/}"
      fi
      ${pkgs.coreutils}/bin/mkdir -p \
        "$PIS_HOME/.pi/agent/extensions" \
        "$PIS_HOME/.config/jj" \
        "$PIS_HOME/.config/git" \
        "$PIS_ETC" \
        "$HOME/.local/share/atuin-agent"

      # Copied: a nested sand can't bind them once the host has replaced them under
      # its long-running parent
      ${pkgs.coreutils}/bin/cp -f /etc/resolv.conf /etc/passwd /etc/group "$PIS_ETC/"

      unset ${
        lib.concatStringsSep " " [
          "VAULT_TOKEN"
          "AWS_ACCESS_KEY_ID"
          "AWS_SECRET_ACCESS_KEY"
          "AWS_SESSION_TOKEN"
          "AWS_PROFILE"
          "AZURE_CLIENT_ID"
          "AZURE_CLIENT_SECRET"
          "AZURE_TENANT_ID"
          "CLOUDFLARE_API_TOKEN"
          "DIGITALOCEAN_TOKEN"
          "DIGITALOCEAN_ACCESS_TOKEN"
          "GITHUB_TOKEN"
          "GH_TOKEN"
          "GITLAB_TOKEN"
          "GOOGLE_APPLICATION_CREDENTIALS"
          "OPENAI_API_KEY"
          "ANTHROPIC_API_KEY"
          "GEMINI_API_KEY"
          "SSH_AUTH_SOCK"
          "GPG_AGENT_INFO"
          "KRB5CCNAME"
        ]
      }

      export PIS_PROJECT PIS_HOME PIS_ETC
      exec ${lib.getExe piSandbox.config.script} --extension "$HOME/.pi/agent/sandbox.ts" "$@"
    '';
  };

in {
  home = {
    packages = [ pis ];
    sessionVariables.PI_SKIP_VERSION_CHECK = 1;

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

  programs.pi-coding-agent = {
    enable = true;
    package = piCodingAgent;

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
              model = "cpa/gpt-6.1-sol";
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
                "mcp:context7"
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
                "mcp:context7"
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
        "cpa/gpt-6.1-sol"
        "cpa/gpt-6-astra"
        "claude-fable-5-1"
        "flint"
      ];
    };
  };

}
