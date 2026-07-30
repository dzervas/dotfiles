{
  config,
  lib,
  pkgs,
  ...
}:
let
  nodejs = pkgs.nodejs_22; # tree-sitter does not work with nodejs_24
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
  piCodingAgentNodeModules = pkgs.runCommand "pi-coding-agent-node-modules" { } ''
    mkdir -p $out/node_modules/@earendil-works
    ln -s ${pkgs.pi-coding-agent-latest}/lib/node_modules/pi-monorepo \
      $out/node_modules/@earendil-works/pi-coding-agent
  '';
  piCodingAgent = pkgs.symlinkJoin {
    name = "pi-coding-agent-with-extension-node-path";
    paths = [ pkgs.pi-coding-agent-latest ];
    nativeBuildInputs = [ pkgs.makeWrapper ];
    # Pi realpaths symlinked extensions before loading them, so bare imports
    # need to resolve from the extension dependency closure while pi runs.
    # Async subagent runners also need the Nix-installed Pi package exposed under
    # its package name for detached module resolution.
    postBuild = ''
      wrapProgram $out/bin/pi \
        --prefix NODE_PATH : ${piExtensionNodeModules}/node_modules \
        --prefix NODE_PATH : ${piCodingAgentNodeModules}/node_modules
        # --prefix NODE_OPTIONS " " "--conditions=import"
    '';
  };

  # TODO: @hypabolic/pi-hypa, does tool call compaction on the fly
  piPackages = [
    "npm:pi-mcp-adapter@2.11.0"
    "npm:pi-web-access@0.13.0"
    "npm:pi-readseek@0.8.19"
    "npm:@gotgenes/pi-anthropic-auth@2.0.0"
    "npm:@gotgenes/pi-subagents@19.2.1"
    {
      source = "npm:@router-for-me/pi-cliproxyapi-provider@1.4.8";
      # Disable tps.ts that shows elapsed n stuff, it's ugly
      extensions = [ "index.ts" ];
    }
  ];
  piPackagesSources = map (p: p.source or p) piPackages;

  piNpmPrefix = "${config.home.homeDirectory}/.pi/agent/npm-global";

  piSettings = rec {
    quietStartup = true;
    collapseChangelog = true;
    enableInstallTelemetry = false;
    showHardwareCursor = true;
    transport = "auto";
    terminal = {
      showTerminalProgress = true;
      clearOnShrink = true;
    };
    warnings.anthropicExtraUsage = false;

    packages = piPackages;
    npmCommand = [
      "${nodejs}/bin/npm"
      "--prefix"
      piNpmPrefix
    ];

    defaultModel = builtins.elemAt enabledModels 0;
    defaultThinkingLevel = "medium";
    enabledModels = [ "gpt-5.6-sol" "claude-opus-5" "gpt-5.6-terra" "claude-fable-5" ];

    subagents = {
      defaultModel = "claude-sonnet-5";
      agentOverrides = let
        smallModel = "claude-haiku-4-5";
      in {
        scout.model = smallModel; # Local file recon
        researcher.model = smallModel; # Web recon
        delegate.model = smallModel; # Small worker

        oracle.model = piSettings.defaultModel; # Plan reviewer
        reviewer.model = piSettings.defaultModel; # Code reviewer
      };
    };

    readseek = {
      replacedTools = [ "read" "edit" "write" "grep" ];
      syntaxValidation = "warn";
      display = {
        read = "compact";
        grep = "compact";
        edit = "expanded";
        write = "expanded";
      };
    };
  };

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
      resolved_specs=()

      for spec in "''${specs[@]}"; do
        case "$spec" in
          npm:*@*) ;;
          *)
            echo "Pi package must be pinned as npm:<package>@<version>: $spec" >&2
            exit 1
            ;;
        esac

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

      block="$({
        echo "  piPackages = ["
        for spec in "''${resolved_specs[@]}"; do
          echo "    \"$spec\""
        done
        echo "  ];"
      })"

      PI_PACKAGES_BLOCK="$block" AI_NIX="$ai_nix" python3 -c '
      import os
      import re
      from pathlib import Path

      path = Path(os.environ["AI_NIX"])
      block = os.environ["PI_PACKAGES_BLOCK"]
      text = path.read_text()
      new_text, count = re.subn(r"  piPackages = \[\n.*?\n  \];", block, text, count=1, flags=re.S)
      if count != 1:
        raise SystemExit(f"Could not find piPackages block in {path}")
      if new_text != text:
        path.write_text(new_text)
      '
    '';
  };
in
{
  home = {
    packages = with pkgs; [
      lmstudio
      bubblewrap # for codex
      openspec
      piExtensionBump
      snyk
    ];

    sessionVariables = {
      OPENSPEC_TELEMETRY = 0;
      PI_SKIP_VERSION_CHECK = 1;
    };
    file = {
      ".pi/agent/AGENTS.md".source =
        config.lib.file.mkOutOfStoreSymlink "${config.home.homeDirectory}/Lab/dotfiles/pi/global_agents.md";
      ".pi/agent/extensions".source =
        config.lib.file.mkOutOfStoreSymlink "${config.home.homeDirectory}/Lab/dotfiles/pi/extensions";
      ".pi/agent/skills".source =
        config.lib.file.mkOutOfStoreSymlink "${config.home.homeDirectory}/Lab/dotfiles/pi/skills";
      ".pi/agent/node_modules".source = piExtensionNodeModules + "/node_modules";
    };
  };

  programs = {
    codex.enable = true;
    pi-coding-agent = {
      enable = true;
      package = pkgs.pi-coding-agent-latest;
      extraPackages = with pkgs; [
        nodejs
        typescript
        piCodingAgent
      ];

      settings = rec {
        quietStartup = true;
        collapseChangelog = true;
        enableInstallTelemetry = false;

        showHardwareCursor = true;
        terminal = {
          showTerminalProgress = true;
          clearOnShrink = true;
        };

        transport = "auto";
        warnings.anthropicExtraUsage = false;

        packages = piPackages;
        npmCommand = [
          "${nodejs}/bin/npm"
          "--prefix"
          piNpmPrefix
        ];

        defaultModel = builtins.elemAt enabledModels 0;
        defaultThinkingLevel = "medium";
        enabledModels = [ "gpt-5.6-sol" "claude-opus-5" "gpt-5.6-terra" "claude-fable-5" ];

        subagents = {
          defaultModel = "claude-sonnet-5";
          agentOverrides = let
            smallModel = "claude-haiku-4-5";
          in {
            scout.model = smallModel; # Local file recon
            researcher.model = smallModel; # Web recon
            delegate.model = smallModel; # Small worker

            oracle.model = piSettings.defaultModel; # Plan reviewer
            reviewer.model = piSettings.defaultModel; # Code reviewer
          };
        };
      };
    };
  };
}
