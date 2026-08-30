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
    ln -s ${pkgs.pi-coding-agent}/lib/node_modules/pi-monorepo \
      $out/node_modules/@earendil-works/pi-coding-agent
  '';
  piCodingAgent = pkgs.symlinkJoin {
    name = "pi-coding-agent-with-extension-node-path";
    paths = [ pkgs.pi-coding-agent ];
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

  # TODO: @hypabolic/pi-hypa, does tool call compaction on the fly
  piPackages = [
    "npm:pi-mcp-adapter@2.27.0"
    "npm:pi-web-access@0.24.2"
    "npm:@gotgenes/pi-anthropic-auth@2.0.6"
    "npm:@gotgenes/pi-subagents@19.3.5"
    {
      source = "npm:@router-for-me/pi-cliproxyapi-provider@1.4.13";
      # Disable tps.ts that shows elapsed n stuff, it's ugly
      extensions = [ "index.ts" ];
    }
    {
      source = "git:github.com/mattpocock/skills";
      skills = [
        "skills/engineering/grill-with-docs/SKILL.md"
        "skills/engineering/wayfinder/SKILL.md"
        "skills/engineering/domain-modeling/SKILL.md"
        "skills/engineering/research/SKILL.md"
        "skills/engineering/prototype/SKILL.md"
        "skills/engineering/tdd/SKILL.md"
        "skills/engineering/diagnosing-bugs/SKILL.md"
        "skills/engineering/codebase-design/SKILL.md"
        "skills/engineering/code-review/SKILL.md"
        "skills/productivity/grill-me/SKILL.md"
        "skills/productivity/grilling/SKILL.md"
        "skills/productivity/writing-for-agents/SKILL.md"
      ];
    }
  ];
  piPackagesSources = map (p: p.source or p) piPackages;

  piSettings = rec {
    quietStartup = true;
    collapseChangelog = true;
    enableInstallTelemetry = false;
    showHardwareCursor = true;
    showCacheMissNotices = true;
    transport = "auto";
    terminal = {
      showTerminalProgress = true;
      clearOnShrink = true;
    };
    warnings.anthropicExtraUsage = false;

    packages = piPackages;
    npmCommand = [ "${nodejs}/bin/npm" ];

    defaultModel = builtins.elemAt enabledModels 0;
    # defaultProvider = "cliproxyapi";
    defaultThinkingLevel = "medium";
    enabledModels = [
      "gpt-5.6-sol"
      "claude-opus-5"
      "gpt-5.6-terra"
      "claude-fable-5"

      "qwen3"
      "ornith"
      "ornith9"
    ];

    subagents = {
      defaultModel = "claude-sonnet-5";
      agentOverrides =
        let
          smallModel = "claude-haiku-4-5";
        in
        {
          scout.model = smallModel; # Local file recon
          researcher.model = smallModel; # Web recon
          delegate.model = smallModel; # Small worker

          oracle.model = piSettings.defaultModel; # Plan reviewer
          reviewer.model = piSettings.defaultModel; # Code reviewer
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
in
{
  home = {
    packages = with pkgs; [
      lmstudio
      bubblewrap # for codex
      openspec
      piExtensionBump
      snyk
      codegraph
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
      ".pi/agent/mcp.json".source =
        config.lib.file.mkOutOfStoreSymlink "${config.home.homeDirectory}/Lab/dotfiles/pi/mcp.json";
      ".pi/agent/node_modules".source = piExtensionNodeModules + "/node_modules";
    };
  };

  programs = {
    codex.enable = true;
    pi-coding-agent = {
      enable = true;
      package = piCodingAgent;
      extraPackages = with pkgs; [
        nodejs
        typescript
      ];

      settings = piSettings;
    };
  };
}
