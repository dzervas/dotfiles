{
  config,
  lib,
  pkgs,
  ...
}:
let
  tools = mcp: tools: map (t: "mcp__${mcp}__${t}") tools;

  nodejs = pkgs.nodejs_22; # tree-sitter does not work with nodejs_24
  piImportNpmLock = pkgs.callPackage (pkgs.path + "/pkgs/build-support/node/import-npm-lock") {
    callPackages = pkgs.newScope { inherit nodejs; };
  };
  piExtensionNodeModules = piImportNpmLock.buildNodeModules {
    inherit nodejs;
    npmRoot = ../pi/extensions;

    derivationArgs = {
      doCheck = true;
      checkPhase = ''
        npm audit
      '';
    };
  };

  piPackages = [
    "npm:pi-subagents@0.12.4"
    "npm:context-mode@1.0.72"
    "npm:pi-mcp-adapter@2.2.2"
  ];

  piNpmPrefix = "${config.home.homeDirectory}/.pi/agent/npm-global";

  piSettings = {
    packages = piPackages;
    npmCommand = [
      "${nodejs}/bin/npm"
      "--prefix"
      piNpmPrefix
    ];
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
      specs=(${lib.escapeShellArgs piPackages})
      cutoff="$(date -u -d '30 days ago' +%F)"
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
          if snyk test "$package@$candidate" --severity-threshold=low; then
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
      github-copilot-cli
      piExtensionBump

      pi-coding-agent-latest
      nodejs # used too much to ignore :/
      snyk
      typescript
    ];

    sessionVariables = {
      OPENSPEC_TELEMETRY = 0;
    };
    file = {
      ".pi/agent/AGENTS.md".source =
        config.lib.file.mkOutOfStoreSymlink "${config.home.homeDirectory}/Lab/dotfiles/pi/global_agents.md";
      ".pi/agent/extensions".source =
        config.lib.file.mkOutOfStoreSymlink "${config.home.homeDirectory}/Lab/dotfiles/pi/extensions";
      ".pi/agent/node_modules".source = piExtensionNodeModules + "/node_modules";
      ".pi/agent/settings.json".text = builtins.toJSON piSettings;
    };
  };

  programs = {
    codex = {
      enable = true;
      package = pkgs.codex-latest;
    };

    # TODO: Add skills: https://docs.claude.com/en/docs/claude-code/skills
    claude-code = {
      enable = true;
      # package = pkgs.claude-code-latest;
      settings = {
        model = "opusplan";
        enableAllProjectMcpServers = false;
        includeCoAuthoredBy = false;
        alwaysThinkingEnabled = true;
        statusLine = {
          command = "input=$(cat); echo \"[$(echo \"$input\" | jq -r '.model.display_name')]  $(basename \"$(echo \"$input\" | jq -r '.workspace.current_dir')\")\"";
          padding = 0;
          type = "command";
        };

        permissions = {
          # defaultMode = "acceptEdits";
          disableBypassPermissionsMode = "disable";

          allow = [
            "Bash(cargo check:*)"
            "Bash(cargo build:*)"
            "Bash(cargo test:*)"
            "Bash(git diff:*)"
            "Bash(git log:*)"
            "Bash(git status:*)"
            "Bash(jj diff:*)"
            "Bash(jj log:*)"
            "Bash(jj status:*)"
            "Bash(hurl:*)"
            "Bash(nix run .)"
            "Bash(statix check:*)"

            "Read(~/.claude/plugins/cache/superpowers/skills/*)"

            "WebSearch"
            "WebFetch(domain:hurl.dev)"

            "Skill(openspec:*)"

            "Search(path: ., *)"
          ]
          ++ (tools "grafana" [
            "find_*"
            "fetch_*"
            "get_*"
            "generate_deeplink"
            "list_*"
            "query_*"
            "search_dashboards"
          ]);
          ask = [ ];
          deny = [
            "Bash(git add:*)"
            "Bash(git commit:*)"
            "Bash(git push:*)"
            "Bash(git merge:*)"
            "Bash(su:*)"
            "Bash(sudo:*)"
            "Bash(home-manager switch:*)"
            "Bash(nixos-rebuild switch:*)"

            "Read(~/.aws)"
            "Read(~/.ssh)"
            "Read(./.env)"
            "Read(./.envrc)"
            "Read(./.direnv)"
          ];
        };

        env = {
          # ANTHROPIC_BASE_URL = "https://ai.vpn.dzerv.art";
          # ANTHROPIC_AUTH_TOKEN = "sk-dummy";
          # API_TIMEOUT_MS = "3000000";

          # ANTHROPIC_DEFAULT_OPUS_MODEL = "gpt-5.4(medium)";
          # ANTHROPIC_DEFAULT_SONNET_MODEL = "gpt-5.4(medium)";
          # ANTHROPIC_DEFAULT_HAIKU_MODEL = "glm-4.7";
          # CLAUDE_CODE_SUBAGENT_MODEL = "gpt-5.4(high)";

          CLAUDE_CODE_ENABLE_TELEMETRY = "1";
          OTEL_METRICS_EXPORTER = "otlp";
          OTEL_EXPORTER_OTLP_METRICS_ENDPOINT = "https://metrics.vpn.dzerv.art/opentelemetry/v1/metrics";
          OTEL_EXPORTER_OTLP_METRICS_PROTOCOL = "http/protobuf";
        };
      };
    };
  };
}
