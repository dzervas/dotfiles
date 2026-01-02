{ pkgs, ... }: let
  tools = mcp: tools: builtins.map(t: "mcp__${mcp}__${t}") tools;
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
            "WebFetch(domain:docs.rs)"
            "WebFetch(domain:github.com)"
            "WebFetch(domain:nix-community.github.io)"
            "WebFetch(domain:hurl.dev)"
            "WebFetch(domain:registry.terraform.io)"

            "Search"
          ] ++ (tools "grafana" [
              "find_error_pattern_logs"
              "find_slow_requests"
              "fetch_pyroscope_profile"

              "get_alert_rule_by_uid"
              "get_dashboard_by_uid"
              "get_dashboard_panel_queries"
              "get_dashboard_property"
              "get_dashboard_summary"
              "get_datasource_by_uid"
              "get_datasource_by_name"
              "get_incident"
              "get_oncall_shift"
              "get_current_oncall_users"
              "get_sift_investigation"
              "get_sift_analysis"
              "get_assertions"
              "generate_deeplink"

              "list_alert_rules"
              "list_contact_points"
              "list_datasources"
              "list_loki_label_names"
              "list_loki_label_values"
              "list_oncall_schedules"
              "list_oncall_teams"
              "list_oncall_users"
              "list_prometheus_metric_metadata"
              "list_prometheus_metric_names"
              "list_prometheus_label_names"
              "list_prometheus_label_values"
              "list_prometheus_label_values"
              "list_pyroscope_label_names"
              "list_pyroscope_label_values"
              "list_pyroscope_profile_types"
              "list_sift_investigations"
              "list_teams"
              "list_users_by_org"

              "query_loki_logs"
              "query_loki_stats"
              "query_prometheus"

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
          ANTHROPIC_BASE_URL = "https://ai.vpn.dzerv.art";
          ANTHROPIC_AUTH_TOKEN = "sk-dummy";
          API_TIMEOUT_MS = "3000000";

          ANTHROPIC_DEFAULT_OPUS_MODEL = "gemini-claude-opus-4-5-thinking";
          ANTHROPIC_DEFAULT_SONNET_MODEL = "gpt-5.2-codex(medium)";
          ANTHROPIC_DEFAULT_HAIKU_MODEL = "glm-4.7";
          CLAUDE_CODE_SUBAGENT_MODEL = "gpt-5.2-codex(high)";
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
