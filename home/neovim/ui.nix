{ lib, ... }: {
  programs.nixvim.plugins = {
    # Buffer view helpers
    bufferline = {
      enable = true;
      settings = {
        options = {
          always_show_bufferline = false; # When there's 1 buffer, don't show the bufferline
          diagnostics = "nvim_lsp"; # Show LSP diagnostics
          separator_style = "slant"; # Slanted separators
        };
      };
    };

    lualine = {
      enable = true;
      settings = {
        options.globalstatus = true;
        sections = {
          lualine_c = [{
            __unkeyed-1 = "filename";
            path = 1; # Relative path
          }];
          lualine_z = lib.mkAfter [{
            __unkeyed-1.__raw = ''
                function()
                  -- Check if CopilotManager exists and copilot is loaded
                  if _G.CopilotManager == nil or package.loaded["copilot"] == nil then
                    return "";
                  end

                  -- Check if copilot is enabled via our management system
                  local project_root = _G.CopilotManager.get_project_root()
                  local project_enabled =
                  _G.CopilotManager.is_copilot_enabled_for_project(project_root)
                  local buffer_enabled = _G.CopilotManager.is_copilot_enabled_for_buffer()

                  if project_enabled or buffer_enabled then
                    return " "
                  end

                  return " ";
                end
                '';
            color.fg = "#ffffff";
          }];
        };
      };
    };

    noice = {
      enable = true;
      settings = {
        lsp = {
          progress = {
            enabled = true;
            throttle = 100;
          };
          override = {
            "vim.lsp.util.convert_input_to_markdown_lines" = true;
            "vim.lsp.util.stylize_markdown" = true;
          };
        };
        presets = {
          bottom_search = true;
          command_palette = true;
          long_message_to_split = true;
          inc_rename = true;
        };
      };
    };

    telescope = {
      enable = true;
      # TODO: Lazy load
      keymaps = {
        "<A-f>" = "find_files";
        "<A-j>" = "lsp_document_symbols";
        "<A-r>" = "commands";
        "<A-z>" = "zoxide list";
        "<A-Tab>" = "buffers";
        "<C-F>" = "live_grep";
        "<C-Z>" = "undo";
      };

      extensions = {
        fzf-native.enable = true;
        zoxide.enable = true;
        ui-select = {
          enable = true;
          settings = {
            specific_opts = {
              codeactions = false; # Keep LSP code actions in the default UI
            };
          };
        };
        undo.enable = true;
      };
    };

    # Better code diagnostics
    trouble = {
      enable = true;
      settings = {
        auto_close = true;
        auto_preview = true;
        focus = true;
      };
    };

    notify = {
      enable = true; # Noice
      settings.background_colour = "#000000";
    };
    web-devicons.enable = true; # Telescope, trouble & neo-tree dep
  };
}
