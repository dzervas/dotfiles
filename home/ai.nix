{ pkgs, ... }:
let
  tools = mcp: tools: map (t: "mcp__${mcp}__${t}") tools;
  anthropic = {
    "claude-opus-4-5-thinking" = "opus-4.5";
    "claude-sonnet-4-5-thinking" = "sonnet-4.5";
    "glm-5" = "glm-5";
  };
  openai = {
    "gpt-5.3-codex(high)" = "gpt-5.3-codex-high";
    "gpt-5.3-codex(medium)" = "gpt-5.3-codex";
    "gpt-5.3(high)" = "gpt-5.3";
  };
  google = {
    "gemini-3-pro-preview" = "gemini-3-pro";
    "gemini-3-flash-preview" = "gemini-3-flash";
  };
  # allModels = anthropic // openai // google;
in
{
  home.packages = with pkgs; [
    # github-copilot-cli
    lmstudio
    # claude-chrome
  ];

  programs = {
    codex = {
      enable = true;
      # package = pkgs.codex-latest;
      settings = {
        personality = "pragmatic";
        model = "gpt-5.3-codex";
        model_reasoning_effort = "medium";

        approval_policy = "untrusted";
        sandbox_mode = "workspace-write";
        sandbox_workspace_write.network_access = true;

        tui.notifications = true;
        file_opener = "none";

        features = {
          remote_models = true;
          runtime_metrics = true;
          use_linux_sandbox_bwrap = true;
        };

        otel.exporter.otlp-http = {
          endpoint = "https://metrics.vpn.dzerv.art";
          protocol = "binary";
        };
      };
    };

    # TODO: Add skills: https://docs.claude.com/en/docs/claude-code/skills
    claude-code = {
      enable = true;
      # package = pkgs.claude-code-latest;
      settings = {
        model = "opus";
        enableAllProjectMcpServers = false;
        includeCoAuthoredBy = false;
        alwaysThinkingEnabled = true;
        statusLine = {
          command = "input=$(cat); echo \"[$(echo \"$input\" | jq -r '.model.display_name')]  $(basename \"$(echo \"$input\" | jq -r '.workspace.current_dir')\")\"";
          padding = 0;
          type = "command";
        };

        # extraKnownMarketplaces.anthropic.source = {
        #   source = "github";
        #   repo = "anthropics/skills";
        # };
        # enabledPlugins."document-skills@anthropic-agent-skills" = true;

        # hooks = {
        #   PreToolUse = [{
        #     matcher = "";
        #     hooks = [{
        #       type = "command";
        #       command = toString ./agentty/hooks/pretooluse.sh;
        #       timeout = 60;
        #     }];
        #   }];
        # };

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
          ANTHROPIC_BASE_URL = "https://ai.vpn.dzerv.art";
          ANTHROPIC_AUTH_TOKEN = "sk-dummy";
          API_TIMEOUT_MS = "3000000";

          ANTHROPIC_DEFAULT_OPUS_MODEL = "gpt-5.3-codex(medium)";
          ANTHROPIC_DEFAULT_SONNET_MODEL = "gpt-5.3-codex(medium)";
          ANTHROPIC_DEFAULT_HAIKU_MODEL = "glm-4.7";
          CLAUDE_CODE_SUBAGENT_MODEL = "gpt-5.3-codex(high)";

          CLAUDE_CODE_ENABLE_TELEMETRY = "1";
          OTEL_METRICS_EXPORTER = "otlp";
          OTEL_EXPORTER_OTLP_METRICS_ENDPOINT = "https://metrics.vpn.dzerv.art/opentelemetry/";
          OTEL_EXPORTER_OTLP_METRICS_PROTOCOL = "http/protobuf";
        };
      };
    };

    # TODO: OPENCODE_EXPERIMENTAL_DISABLE_COPY_ON_SELECT env var
    opencode = {
      enable = true;
      settings = {
        # Awesome stuff: https://github.com/safzanpirani/opencode-configs
        # TODO: Oh-my-opencode
        autoupdate = false;
        share = "disabled";
        model = "dz-anthropic/opus-4.5";
        small_model = "dz-anthropic/glm-5";
        # opencode-cursor-auth
        # plugin = [];

        mode.read-only = {
          model = "dz-openai/gpt-5.3-codex(high)";
          tools = {
            bash = true;
            edit = false;
            write = false;
            read = true;
            grep = true;
            glob = true;
            list = true;
            patch = false;
            todowrite = true;
            todoread = true;
            webfetch = true;
          };
        };

        provider = {
          dz-anthropic = {
            # anthropic = {
            npm = "@ai-sdk/anthropic"; # openai-compatible makes claude models break after each tool call
            name = "DZervArt (Anthropic)";
            options = {
              baseURL = "https://ai.vpn.dzerv.art/v1";
              apiKey = "sk-dummy";
            };
            models = builtins.mapAttrs (_: v: { name = v; }) anthropic;
          };
          dz-openai = {
            npm = "@ai-sdk/openai";
            name = "DZervArt (OpenAI)";
            options = {
              baseURL = "https://ai.vpn.dzerv.art/v1";
              apiKey = "sk-dummy";
            };
            models = builtins.mapAttrs (_: v: { name = v; }) (openai // google);
          };
        };

        formatter = {
          cargo = {
            command = [
              "cargo"
              "fmt"
            ];
            extensions = [ ".rs" ];
          };
          terraform = {
            command = [
              "terraform"
              "fmt"
            ];
            extensions = [
              ".tf"
              ".hcl"
            ];
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
