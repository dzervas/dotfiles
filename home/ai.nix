{ pkgs, ... }:
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
in
{
  home = {
    packages = with pkgs; [
      lmstudio
      bubblewrap # for codex
      openspec

      pi-coding-agent
      nodejs # used too much to ignore :/
    ];

    sessionVariables = {
      OPENSPEC_TELEMETRY = 0;
      # Disable update checks, telemetry, etc.
      PI_OFFLINE = 1;
    };
    file = {
      ".pi/agent/AGENTS.md".source = ../pi/global_agents.md;
      ".pi/agent/extensions".source = ../pi/extensions;
      ".pi/agent/node_modules".source = piExtensionNodeModules + "/node_modules";
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
      package = pkgs.claude-code-latest;
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
