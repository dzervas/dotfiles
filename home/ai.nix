{ pkgs, ... }: let
  tools = mcp: tools: map(t: "mcp__${mcp}__${t}") tools;
  models = {
    "gemini-claude-opus-4-5-thinking" = "opus-4.5";
    "gpt-5.2-codex(medium)" = "gpt-5.2-codex";
    "glm-4.7" = "glm-4.7";
    "gemini-sonnet-claude-4-5-thinking" = "sonnet-4.5";

    "gpt-5.2(high)" = "gpt-5.2";
    "gpt-5.2-codex(high)" = "gpt-5.2-codex-high";
    "gemini-3-pro-preview" = "gemini-3-pro";
  };
in {
  home.packages = with pkgs; [
    github-copilot-cli
    lmstudio
    openspec
  ];

  programs = {
    codex = {
      enable = true;
      # package = pkgs.codex-latest;
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
          defaultMode = "acceptEdits";
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
            "Bash(yarn test)"
            "Bash(statix check:*)"

            "Read(~/.claude/plugins/cache/superpowers/skills/*)"

            "WebSearch"
            "WebFetch(domain:nix-community.github.io)"
            "WebFetch(domain:hurl.dev)"

            "Skill(openspec:*)"

            "Search(*)"
          ] ++ (tools "grafana" [
              "find_*"
              "fetch_*"
              "get_*"
              "generate_deeplink"
              "list_*"
              "query_*"
              "search_dashboards"
            ]);
          ask = [];
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

          # ANTHROPIC_DEFAULT_OPUS_MODEL = "gemini-claude-opus-4-5-thinking";
          # ANTHROPIC_DEFAULT_SONNET_MODEL = "gpt-5.2-codex(medium)";
          # ANTHROPIC_DEFAULT_HAIKU_MODEL = "glm-4.7";
          # CLAUDE_CODE_SUBAGENT_MODEL = "gpt-5.2-codex(high)";

          CLAUDE_CODE_ENABLE_TELEMETRY = "1";
          OTEL_METRICS_EXPORTER = "otlp";
          OTEL_EXPORTER_OTLP_METRICS_ENDPOINT = "https://metrics.vpn.dzerv.art/opentelemetry/";
          OTEL_EXPORTER_OTLP_METRICS_PROTOCOL = "http/protobuf";
        };
      };
    };

    opencode = {
      enable = true;
      settings = {
        autoupdate = false;
        share = "disabled";
        # keybinds.leader = "space";

        provider.dzervart = {
          npm = "@ai-sdk/openai-compatible";
          name = "DZervArt";
          options = {
            baseURL = "https://ai.vpn.dzerv.art/v1";
            apiKey = "sk-dummy";
          };
          models = builtins.mapAttrs (_: v: { name = v; }) models;
        };

        formatter = {
          cargo = {
            command = ["cargo" "fmt"];
            extensions = [".rs"];
          };
          terraform = {
            command = ["terraform" "fmt"];
            extensions = [".tf" ".hcl"];
          };
        };

        permission = {
          bash = {
            "hurl *" = "allow";

            "cargo build" = "allow";
            "cargo check" = "allow";
            "cargo test" = "allow";
            "cargo run" = "allow";

            "terraform *" = "deny";

            "git commit *" = "deny";
            "git push *" = "deny";

            "*" = "ask";
          };
        };
      };
    };
  };
}
