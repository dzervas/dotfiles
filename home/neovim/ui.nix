{ inputs, lib, pkgs, ... }: let
  inherit (inputs.nixvim.lib.nixvim) utils;
in {
  programs.nixvim.plugins = {
    # Buffer view helpers
    barbar = {
      enable = true;
      settings = {
        auto_hide = 1;
        exclude_name = ["package.json" "Cargo.toml"];
        hide.extensions = true;
        icons.preset = "slanted";
      };
    };

    # TODO: Show jj status instead of git
    lualine = {
      enable = true;
      settings = {
        extensions = [
          "avante"
          "fzf"
          "neo-tree"
          "nvim-dap-ui"
          "quickfix"
          "trouble"
        ];

        options.globalstatus = true;
        sections = {
          lualine_c = [
            (utils.listToUnkeyedAttrs ["filename"] // {
              path = 1; # Relative path
            })
          ];
          lualine_x = [
            (utils.listToUnkeyedAttrs ["tabs"] // {
              mode = 1; # Tab name
              path = 3; # Absolute path with ~
              show_modified_status = false;
              tab_max_length = 20;
              use_mode_colors = true;

              fmt = utils.mkRaw ''
                -- Show the tab's cwd instead of the active filename
                function(name, ctx)
                  local dir = vim.fn.getcwd(-1, ctx.tabnr)
                  return (dir == "")
                    and "[New Tab]"
                    or vim.fn.fnamemodify(dir, ":~")
                end
              '';
            })
          ];
          lualine_z = lib.mkAfter ["copilot"];
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
        # Route vim.notify to snacks.notifier
        routes = [
          { view = "notify"; filter.event = "notify"; }
        ];
      };
    };

    telescope = {
      enable = true;
      keymaps = {
        "<A-a>" = "project";
        "<A-f>" = "find_files";
        "<A-j>" = "lsp_document_symbols";
        "<A-r>" = "commands";
        "<A-z>" = "zoxide list";
        "<C-F>" = "live_grep";
        "<C-Z>" = "undo";
      };

      extensions = {
        fzf-native.enable = true;
        zoxide = {
          enable = true;
          # Do tcd instead of cd
          settings.mappings = {
            default.action = utils.mkRaw "function(selection) vim.cmd.tcd(selection.path) end";
            "<C-t>".action = utils.mkRaw "function(selection) vim.cmd('tabnew'); vim.cmd.tcd(selection.path) end";
          };
        };
        project = {
          enable = true;
          settings = {
            base_dirs = ["~/Lab" "~/Lab/plasma"];
            hidden_files = true;
            sync_with_nvim_tree = true;
            cd_scope = ["tab"];
          };
        };
        ui-select = {
          enable = true;
          settings.specific_opts.codeactions = false; # Keep LSP code actions in the default UI
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
  programs.nixvim.extraPlugins = with pkgs.vimPlugins; [ copilot-lualine ]; # satellite-nvim is fucking everything up
}
