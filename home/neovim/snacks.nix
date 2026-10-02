{ inputs, pkgs, ... }:
let
  inherit (inputs.nixvim.lib.nixvim) utils;
  listAndAttrs = action: attrs: utils.listToUnkeyedAttrs [ action ] // attrs;
  terminalTitle = ''
    function(self)
      local terminals = Snacks.terminal.list()
      table.sort(terminals, function(a, b) return vim.b[a.buf].snacks_terminal.id < vim.b[b.buf].snacks_terminal.id end)
      local titles = {}
      for _, terminal in ipairs(terminals) do
        local label = ("%d: %s"):format(vim.b[terminal.buf].snacks_terminal.id,
          vim.b[terminal.buf].term_title or "Terminal")
        titles[#titles + 1] = { terminal == self and (" [" .. label .. "] ") or (" " .. label .. " "), "FloatBorder" }
      end
      self:set_title(titles)
    end
  '';
  cycleTerminal = direction: utils.mkRaw ''
    function(self)
      local terminals = Snacks.terminal.list()
      table.sort(terminals, function(a, b)
        return vim.b[a.buf].snacks_terminal.id < vim.b[b.buf].snacks_terminal.id
      end)
      for i, terminal in ipairs(terminals) do
        if terminal == self then
          self:hide()
          terminals[((i - 1 + (${toString direction})) % #terminals) + 1]:show():focus()
          return
        end
      end
    end
  '';
in
{
  programs.nixvim = {
    plugins.treesitter.settings.parsers.norg_meta.enable = true; # picker likes it
    plugins.snacks = {
      enable = true;

      settings = {
        # Handle large files efficiently
        bigfile.enabled = true;

        dashboard = {
          sections = [
            { section = "header"; }
            {
              section = "keys";
              gap = 1;
              padding = 1;
            }
            {
              pane = 2;
              icon = " ";
              title = "Projects";
              section = "projects";
              indent = 2;
              padding = 2;
            }
          ];
        };

        explorer = {
          replace_netrw = true;
          trash = false;
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

        styles.notification.focusable = false;

        # Notification system (integrates with vim.notify)
        notifier = {
          enabled = true;
          timeout = 3000;
          style = "minimal";
          top_down = true;
        };

        # Replace the default vim.ui.input command-line prompt with a floating input
        input.enabled = true;

        # TODO: How to put all entries in quickfix?
        picker = {
          enabled = true;
          # TODO: Not working :/
          db.sqlite3_path = "${pkgs.sqlite}/lib/libsqlite3.so";

          # sources.select.layout.preset = "dropdown";
          # sources.select.layout.layout = {
          # relative = "cursor";
          # row = 1;
          # col = 0;
          # };

          # Close the picker on <Esc>
          win.input.keys."<Esc>" = listAndAttrs "close" {
            mode = utils.listToUnkeyedAttrs [
              "n"
              "i"
            ];
          };

          # Replace the default vim.ui.select numbered menu with the picker
          ui_select = true;

          sources = {
            zoxide = {
              confirm = utils.mkRaw ''
                function(picker, item)
                  picker:close()
                  vim.cmd.tcd(item.file)
                  vim.defer_fn(Snacks.picker.files, 100)
                end
              '';

              # Ctrl-t to open in a new tab
              # TODO: the picker (first arg) is not a "normal" picker and it doesn't have a way to get the current item
              win.input.keys."<c-t>" =
                listAndAttrs
                  (utils.mkRaw ''
                    function(_)
                      vim.cmd("tabnew")
                    end
                  '')
                  {
                    mode = utils.listToUnkeyedAttrs [
                      "n"
                      "i"
                    ];
                  };
            };
            files.hidden = true;
          };
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

        terminal =
          let
            default_size = 0.8;
          in
          {
            enabled = true;
            win = {
              position = "float";
              border = "rounded";
              style = "terminal";

              # fixbuf = true;
              resize = true;

              height = default_size;
              width = default_size;

              wo.winbar = "";
              title_pos = "left";
              on_win = utils.mkRaw terminalTitle;
              on_buf = utils.mkRaw ''
                function(self)
                  local update_title = ${terminalTitle}
                  -- Register before Snacks' auto-close handler removes the window.
                  vim.api.nvim_create_autocmd("TermClose", {
                    group = self.augroup,
                    buffer = self.buf,
                    callback = function()
                      if vim.v.event.status ~= 0 or not self:win_valid() then return end
                      local id = vim.b[self.buf].snacks_terminal.id
                      vim.schedule(function()
                        local terminals = Snacks.terminal.list()
                        table.sort(terminals, function(a, b) return vim.b[a.buf].snacks_terminal.id < vim.b[b.buf].snacks_terminal.id end)
                        local previous = terminals[#terminals]
                        for _, terminal in ipairs(terminals) do
                          if vim.b[terminal.buf].snacks_terminal.id < id then previous = terminal end
                        end
                        if previous then previous:show():focus() end
                      end)
                    end,
                  })
                  self:on({ "TermRequest", "TextChanged", "TextChangedT" }, function()
                    vim.schedule(function()
                      if self:win_valid() then update_title(self) end
                    end)
                  end, { buf = true })
                end
              '';
            };
          };
        styles.terminal.keys =
          let
            keymap =
              {
                key,
                action,
                desc,
                mode ? "",
              }:
              utils.listToUnkeyedAttrs [
                key
                action
              ]
              // {
                inherit desc mode;
              };
          in
          {
            new = keymap {
              key = "<A-Return>";
              action = utils.mkRaw ''
                function(self)
                  local count = 0
                  for _, terminal in ipairs(Snacks.terminal.list()) do
                    count = math.max(count, vim.b[terminal.buf].snacks_terminal.id)
                  end
                  self:hide()
                  Snacks.terminal.open(nil, { count = count + 1 })
                end
              '';
              desc = "Open another terminal";
              mode = [
                "n"
                "t"
              ];
            };
            next = keymap {
              key = "<A-Right>";
              action = cycleTerminal 1;
              desc = "Go to next terminal";
              mode = [
                "n"
                "t"
              ];
            };
            prev = keymap {
              key = "<A-Left>";
              action = cycleTerminal (-1);
              desc = "Go to previous terminal";
              mode = [
                "n"
                "t"
              ];
            };
            toggle = keymap {
              key = "<A-Esc>";
              action = "hide";
              desc = "Hide terminal";
              mode = [
                "n"
                "t"
              ];
            };
          };

        # Enhanced status column with git signs
        statuscolumn = {
          enabled = true;
          left = [
            "mark"
            "sign"
          ];
          right = [
            "fold"
            "git"
          ];
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
    };

    # Keybindings for snacks functionality
    # toTable = x: "{" + (
    #   lib.strings.concatStringsSep "," (
    #     lib.attrsets.mapAttrsToList (k: v: "${k}=${v}") x
    #   )
    # ) + "}" ;
    keymaps = [
      # Terminal (replaces floaterm keybinds)
      {
        key = "<A-Esc>";
        mode = [
          "n"
          "t"
        ];
        action = utils.mkRaw "function() Snacks.terminal.toggle() end";
        options.desc = "Toggle terminal";
      }

      # Explorer
      {
        key = "<leader>f";
        action = utils.mkRaw "function() Snacks.explorer() end";
        options.desc = "Show file explorer";
      }

      # Notifications
      {
        key = "<leader>n";
        action = utils.mkRaw "function() Snacks.notifier.show_history() end";
        options.desc = "Show notification history";
      }
      {
        key = "<leader>N";
        action = utils.mkRaw "function() Snacks.notifier.hide() end";
        options.desc = "Dismiss notifications";
      }

      # Picker
      {
        key = "<C-F>";
        action = utils.mkRaw "function() Snacks.picker.grep() end";
        options.desc = "Grep files";
      }
      {
        key = "<C-Z>";
        action = utils.mkRaw "function() Snacks.picker.undo() end";
        options.desc = "Undo history";
      }
      {
        key = "<A-f>";
        action = utils.mkRaw "function() Snacks.picker.files() end";
        options.desc = "Find files";
      }
      {
        key = "<A-r>";
        action = utils.mkRaw "function() Snacks.picker.commands() end";
        options.desc = "Commands";
      }
      {
        key = "<A-z>";
        action = utils.mkRaw "function() Snacks.picker.zoxide() end";
        options.desc = "Projects (zoxide)";
      }
      {
        key = "<leader>gm";
        action = utils.mkRaw "function() Snacks.picker.man() end";
        options.desc = "Man pages";
      }
      {
        key = "<leader>gh";
        action = utils.mkRaw "function() Snacks.picker.help() end";
        options.desc = "Help pages";
      }
      {
        key = "gd";
        action = utils.mkRaw "function() Snacks.picker.lsp_definitions() end";
        options.desc = "Go to definition";
      }
      {
        key = "gD";
        action = utils.mkRaw "function() Snacks.picker.lsp_declarations() end";
        options.desc = "Go to declaration";
      }
      {
        key = "gi";
        action = utils.mkRaw "function() Snacks.picker.lsp_implementations() end";
        options.desc = "Go to implementation";
      }
      {
        key = "gp";
        action = utils.mkRaw "function() Snacks.picker.diagnostics() end";
        options.desc = "Go to problems (diagnostics)";
      }
      {
        key = "gr";
        action = utils.mkRaw "function() Snacks.picker.lsp_references() end";
        options.desc = "Go to reference";
      }
      {
        key = "gs";
        action = utils.mkRaw "function() Snacks.picker.lsp_symbols() end";
        options.desc = "Go to symbol";
      }
      {
        key = "gS";
        action = utils.mkRaw "function() Snacks.picker.lsp_symbols() end";
        options.desc = "Go to workspace symbol";
      }
      {
        key = "gy";
        action = utils.mkRaw "function() Snacks.picker.lsp_type_definitions() end";
        options.desc = "Go to t[y]pe definition";
      }

      # Rename
      {
        key = "<S-F2>";
        action = utils.mkRaw "function() Snacks.rename.rename_file() end";
        options.desc = "Rename file";
      }

      # Zen mode
      {
        key = "<leader>z";
        action = utils.mkRaw "function() Snacks.zen() end";
        options.desc = "Toggle Zen mode";
      }
      {
        key = "<leader>Z";
        action = utils.mkRaw "function() Snacks.zen.zoom() end";
        options.desc = "Toggle Zoom";
      }
    ];

    extraPackagesAfter = with pkgs; [
      imagemagick_light # Show images in picker
      ghostscript # Show PDFs in picker
      mermaid-cli # Show mermaid diagrams in picker
    ];
  };
}
