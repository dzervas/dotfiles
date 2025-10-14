{ inputs, pkgs, ... }: let
  inherit (inputs.nixvim.lib.nixvim) utils;
in {
  programs.nixvim = {
    plugins.treesitter.settings.parsers.norg_meta.enable = true; # picker likes it
    plugins.snacks = {
      enable = true;

      settings = {
        # Handle large files efficiently
        bigfile.enabled = true;

        dashboard = {
          enabled = true;
          sections = [
            { section = "header"; }
            { section = "keys"; gap = 1; padding = 1; }
            { pane = 2; icon = " "; title = "Projects"; section = "projects"; indent = 2; padding = 1; }
          ];
        };

        explorer = {
          enabled = true;
          replace_netrw = true;
        };

        # Indent guides
        indent = {
          enabled = true;
          char = "│";
          only_scope = false;
          animate = {
            enabled = true;
            duration = {
              step = 20;
              total = 500;
            };
            easing = "linear";
          };
        };

        # Better vim.ui.input
        input.enabled = true;

        # Notification system (integrates with vim.notify)
        notifier = {
          enabled = true;
          timeout = 3000;
          style = "compact";
          top_down = true;
        };

        picker = {
          enabled = true;
          # TODO: Not working :/
          db.sqlite3_path = "${pkgs.sqlite}/lib/libsqlite3.so";
        };

        # Quick file rendering
        quickfile.enabled = true;
        # LSP-integrated file renaming
        rename.enabled = true;
        # Scope detection and navigation
        scope.enabled = true;

        # Smooth scrolling
        scroll = {
          enabled = true;
          animate = {
            duration = {
              step = 15;
              total = 250;
            };
            easing = "linear";
          };
        };

        terminal = let
          default_size = 0.8;
        in {
          enabled = true;
          win = {
            position = "float";
            border = "rounded";
            style = "terminal";

            fixbuf = true;
            resize = true;

            height = default_size;
            width = default_size;

            wo.winbar = ''(%{b:snacks_terminal.id}/%{luaeval('#require("snacks").terminal.list()')}) %{get(b:, 'term_title', 'No Title')}'';

            # TODO: These don't work :/
            keys = let
              keymap = { action, desc, mode ? "" }: utils.listToUnkeyedAttrs [ action ] // { inherit desc mode; };
            in {
              "<A-Return>" = keymap {
                action = utils.mkRaw "function() Snacks.terminal.open(); return end";
                desc = "Open another terminal";
                mode = ["n" "t"];
              };
              "<A-Right>" = keymap {
                action = utils.mkRaw "function() Snacks.terminal.next(); return end";
                desc = "Go to next terminal";
                mode = ["n" "t"];
              };
              "<A-Left>" = keymap {
                action = utils.mkRaw "function() Snacks.terminal.prev(); return end";
                desc = "Go to previous terminal";
                mode = ["n" "t"];
              };
              "<A-S-F>" = keymap {
                action = utils.mkRaw "function(self) self:maximize() end";
                desc = "Toggle fullscreen";
                mode = ["n" "t"];
              };
              "<A-f>" = keymap {
                action = "<C-\\><C-n>";
                desc = "Go to normal mode";
                mode = "t";
              };
            };
          };
        };

        # Enhanced status column with git signs
        statuscolumn = {
          enabled = true;
          left = ["mark" "sign"];
          right = ["fold" "git"];
          folds = {
            open = false;
            git_hl = false;
          };
        };


        # LSP word references highlighting
        words = {
          enabled = true;
          debounce = 200;
        };

        # Zen mode for distraction-free coding
        zen = {
          enabled = true;
          toggles = {
            dim = true;
            git_signs = false;
            diagnostics = false;
          };
          zoom = {
            width = 0.85;
          };
        };

        # Dim inactive code
        dim = {
          enabled = true;
          scope = {
            min_size = 5;
          };
        };
      };

      luaConfig.post = ''
        function Snacks.terminal.get_buf_id()
          local terminals = Snacks.terminal.list()
          if #terminals <= 1 then return end

          local current_buf = vim.api.nvim_get_current_buf()
          local current_idx = nil
          for i, term in ipairs(terminals) do
            if term.buf == current_buf then
              current_idx = i
              break
            end
          end

          if not current_idx then return nil, nil end

          return current_idx, #terminals
        end

        function Snacks.terminal.next()
          local current_idx, terminals_count = Snacks.terminal.get_buf_id()
          if not current_idx then return end
          local next_idx = (current_idx % terminals_count) + 1
          Snacks.terminal.get(next_idx):show()
        end

        function Snacks.terminal.prev()
          local current_idx, terminals_count = Snacks.terminal.get_buf_id()
          if not current_idx then return end
          local prev_idx = ((current_idx - 2 + terminals_count) % terminals_count) + 1
          Snacks.terminal.get(prev_idx):show()
        end
      '';
    };

    # Keybindings for snacks functionality
    keymaps = [
      # Terminal (replaces floaterm keybinds)
      { key = "<A-Esc>"; mode = ["n" "t"]; action = utils.mkRaw "function() Snacks.terminal.toggle() end"; options.desc = "Toggle terminal"; }

      # Explorer
      { key = "<leader>f"; action = utils.mkRaw "function() Snacks.explorer() end"; options.desc = "Show file explorer"; }

      # Notifications
      { key = "<leader>n"; action = utils.mkRaw "function() Snacks.notifier.show_history() end"; options.desc = "Show notification history"; }
      { key = "<leader>N"; action = utils.mkRaw "function() Snacks.notifier.hide() end"; options.desc = "Dismiss notifications"; }

      # Picker
      { key = "<leader>gm"; action = utils.mkRaw "function() Snacks.picker.man() end"; options.desc = "Man pages"; }
      { key = "<leader>gh"; action = utils.mkRaw "function() Snacks.picker.help() end"; options.desc = "Help pages"; }
      { key = "gd"; action = utils.mkRaw "function() Snacks.picker.lsp_definitions() end"; options.desc = "Go to definition"; }
      { key = "gD"; action = utils.mkRaw "function() Snacks.picker.lsp_declarations() end"; options.desc = "Go to declaration"; }
      { key = "gi"; action = utils.mkRaw "function() Snacks.picker.lsp_implementations() end"; options.desc = "Go to implementation"; }
      { key = "gp"; action = utils.mkRaw "function() Snacks.picker.diagnostics() end"; options.desc = "Go to problems (diagnostics)"; }
      { key = "gr"; action = utils.mkRaw "function() Snacks.picker.lsp_references() end"; options.desc = "Go to reference"; }
      { key = "gs"; action = utils.mkRaw "function() Snacks.picker.lsp_symbols() end"; options.desc = "Go to symbol"; }
      { key = "gy"; action = utils.mkRaw "function() Snacks.picker.lsp_type_definitions() end"; options.desc = "Go to t[y]pe definition"; }

      # Rename
      { key = "<S-F2>"; action = utils.mkRaw "function() Snacks.rename.rename_file() end"; options.desc = "Rename file"; }

      # Zen mode
      { key = "<leader>z"; action = utils.mkRaw "function() Snacks.zen() end"; options.desc = "Toggle Zen mode"; }
      { key = "<leader>Z"; action = utils.mkRaw "function() Snacks.zen.zoom() end"; options.desc = "Toggle Zoom"; }
    ];

    extraPackagesAfter = with pkgs; [
      imagemagick_light # Show images in picker
      ghostscript # Show PDFs in picker
      mermaid-cli # Show mermaid diagrams in picker
    ];
  };
}
