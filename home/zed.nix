{ config, pkgs, ... }: {
  programs.zed-editor = {
    enable = true;
    # https://github.com/modelcontextprotocol/servers/tree/main/src/sequentialthinking
    extensions = [
      "vscode-dark-modern" # Theme
      "colored-zed-icons-theme" # Icons

      # Language support
      "astro"
      "basher"
      "comment" # Highlights TODO/FIXME/etc.
      "dockerfile"
      "fish"
      "html"
      "jsonnet"
      "nix"
      "svelte"
      "toml"
      "tombi" # Toml LSP
      "tree-sitter-query"

      # Snippets
      "html-snippets"
      "javascript-snippets"
      "python-snippets"
      "rust-snippets"
      "svelte-snippets"
      "typescript-snippets"

      "probe-rs"

      # MCP
      "mcp-server-sequential-thinking"
      "mcp-server-github"
      "svelte-mcp"
    ];

    mutableUserSettings = false;
    userSettings = {
      # Theme
      buffer_font_family = "Iosevka Nerd Font";
      buffer_font_size = if config.setup.isLaptop then 18.0 else 16.0;
      icon_theme = "Colored Zed Icons Theme Dark";
      theme = "VSCode Dark Modern";

      # Behavior & UI
      autoscroll_on_clicks = true;
      expand_excerpt_lines = 3;
      double_click_in_multibuffer = "open";
      close_on_file_delete = true;
      minimap.show = "auto";
      gutter.min_line_number_digits = 2;
      relative_line_numbers = true;
      hover_popover_enabled = true;
      snippet_sort_order = "top";
      search.regex = true;
      use_smartcase_search = true;
      title_bar.show_branch_icon = true;
      tabs = {
        show_diagnostics = "errors";
        file_icons = true;
      };

      # Diagnostics
      languages = {
        Rust = {
          format_on_save = "off";
          preferred_line_length = 100;
          hard_tabs = true;
        };
      };

      diagnostics.inline.enabled = true;
      inlay_hints = {
        show_parameter_hints = false;
        show_type_hints = false;
        show_value_hints = true;
        enabled = true;
      };
      show_signature_help_after_edits = true;
      auto_signature_help = true;
      vim_mode = true;

      # AI
      features.edit_prediction_provider = "supermaven";
      agent = {
        play_sound_when_agent_done = true;
        enable_feedback = false;
      };
      language_models.openai_compatible."Z.AI" = {
        api_url = "https://api.z.ai/api/coding/paas/v4";
        available_models = [
          {
            name = "GLM-4.6";
            display_name = "GLM 4.6";
            max_tokens = 200000;
            max_output_tokens = 128000;
            capabilities = {
              tools = true;
              images = true;
              parallel_tool_calls = true;
              prompt_cache_key = true;
            };
          }
          {
            name = "GLM-4.5-Air";
            display_name = "GLM 4.5 Air";
            max_tokens = 204800;
            # capabilities?
            # Other models? (GLM-4.5-X, etc.)
          }
        ];
      };

      # Disable stuff
      calls.mute_on_join = true;
      git.inline_blame.enabled = false;
      collaboration_panel.button = false;
      git_panel.button = false;
      telemetry = {
        diagnostics = false;
        metrics = false;
      };
    };

    extraPackages = with pkgs; [
      nil
      nixd
    ];
  };

  stylix.targets.zed.enable = false;
}
