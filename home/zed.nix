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
      # buffer_font_size = if config.setup.isLaptop then 18.0 else 16.0;
      buffer_font_size = 18;
      icon_theme = "Colored Zed Icons Theme Dark";
      theme = "VSCode Dark Modern";

      # Behavior & UI
      preferred_line_length = 100;
      wrap_guides = [100];
      auto_update = false;
      base_keymap = "VSCode";
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

      load_direnv = "direct";

      # Languages
      hard_tabs = true;
      file_types = {
        shellscript = [".envrc"];
      };

      languages = {
        Rust = {
          format_on_save = "off";
          preferred_line_length = 100;
        };
      };

      private_files = [".envrc" ".env" ".direnv"];

      # Diagnostics
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
        inline_assistant_model = {
            model = "GLM-4.5-Air";
            provider = "Z.AI";
        };
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

    mutableUserKeymaps = false;
    userKeymaps = [
      {
        bindings = {
          alt-right = "pane::ActivateNextItem";
          alt-shift-right = "pane::SwapItemRight";
          alt-left = "pane::ActivatePreviousItem";
          alt-shift-left = "pane::SwapItemLeft";

          # TODO: Cycle docks as well
          alt-up = "workspace::ActivateNextPane";
          alt-down = "workspace::ActivatePreviousPane";

          alt-c = ["pane::CloseActiveItem" { close_pinned = false; }];
          alt-f = "file_finder::Toggle";
          alt-shift-f = "workspace::ToggleZoom";
          alt-shift-o = "pane::CloseOtherItems";
          alt-r = "command_palette::Toggle";
          alt-z = "projects::OpenRecent";

          ctrl-f = "pane::DeploySearch";
        };
      }

      {
        context = "Workspace";
        bindings = {
          alt-escape = "terminal_panel::Toggle";
          alt-s = "project_symbols::Toggle";
        };
      }
      {
        # TODO: Double escape goes to "normal" mode
        context = "Terminal";
        bindings = {
          alt-enter = "workspace::NewTerminal";
          ctrl-f = "buffer_search::Deploy";
        };
      }
      # TODO: Maybe keymap to run the tests and show a small notification or smth?
      # TODO: ctrl-shift- to open the definition in a split
      # TODO: Breakpoint & debugging keymaps
      {
        context = "Editor";
        bindings = {
          # TODO: ctrl-down accept the next completion line
          ctrl-up = "editor::MoveLineUp";
          ctrl-down = "editor::MoveLineDown";
          alt-enter = "pane::SplitVertical";
        };
      }
      # TODO: If no search is initiated and in visual mode, n & N should search for the selection
      {
        context = "vim_mode == normal";
        bindings = {
          # TODO: If no search is initiated, n & N should search for the word under the cursor
          # TODO: If another dock is shown, select the project dock
          "space f" = "workspace::ToggleLeftDock";
          "space w" = "editor::Format";
          "space a a" = "workspace::ToggleRightDock";
        };
      }
      {
        context = "Editor && vim_mode == normal";
        bindings = {
          "g up" = "editor::GoToPreviousDiagnostic";
          "g down" = "editor::GoToDiagnostic";
        };
      }
      {
        context = "(Editor && edit_prediction)";
        bindings = {
          ctrl-right = "editor::AcceptPartialEditPrediction";
        };
      }
      {
        context = "(Editor && edit_prediction_conflict)";
        bindings = {
          ctrl-right = "editor::AcceptPartialEditPrediction";
        };
      }
      {
        # TODO: Escape in normal mode should exit
        # TODO: Ctrl-s should focus replace?
        context = "BufferSearchBar || ProjectSearchView || ProjectSearchBar";
        bindings = {
          ctrl-s = "search::ToggleReplace";
        };
      }
      {
        context = "ProjectPanel && not_editing";
        bindings = {
          a = "project_panel::NewFile";
          d = "project_panel::Delete";
          r = "project_panel::Rename";
          "g up" = "project_panel::SelectPrevDiagnostic";
          "g down" = "project_panel::SelectNextDiagnostic";
        };
      }
    ];

    extraPackages = with pkgs; [
      nil
      nixd
    ];
  };

  stylix.targets.zed.enable = false;
}
