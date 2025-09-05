{ inputs, pkgs, ... }: let
  tools = mcp: tools: builtins.map(t: "mcp__${mcp}__${t}") tools;
in {
  home.packages = with pkgs; [
    inputs.claude-desktop.packages.${pkgs.system}.claude-desktop-with-fhs
    cursor-cli
    codex
  ];

  programs.claude-code = {
    enable = true;
    settings = {
      model = "opusplan";
      enableAllProjectMcpServers = false;
      includeCoAuthoredBy = false;
      statusLine = {
        command = "input=$(cat); echo \"[$(echo \"$input\" | jq -r '.model.display_name')]  $(basename \"$(echo \"$input\" | jq -r '.workspace.current_dir')\")\"";
        padding = 0;
        type = "command";
      };

      permissions = {
        defaultMode = "acceptEdits";
        disableBypassPermissionsMode = "disable";
        # additionalDirectories = [];

        allow = [
          "Bash(cargo check:*)"
          "Bash(cargo build:*)"
          "Bash(cargo test:*)"
          "Bash(git diff:*)"
          "Bash(hurl:*)"
          "Bash(nix run .)"
          "Bash(yarn test)"
          "Bash(statix check:*)"

          "WebSearch"
          "WebFetch(domain:docs.rs)"
          "WebFetch(domain:github.com)"
          "WebFetch(domain:nix-community.github.io)"
          "WebFetch(domain:hurl.dev)"
          "WebFetch(domain:registry.terraform.io)"
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
        ask = [
          "Bash(git commit:*)"
          "Bash(git push:*)"
        ];
        deny = [
          "Read(./.env)"
          "Read(./.envrc)"
          "Read(./.direnv)"
        ];
      };
    };
  };
}
