{ lib, pkgs, ... }: {
# Issues:
# - Run python script with args/env (nvim-iron?)
# - Set up nvim-dap
# - Copilot save per folder/git?
# - Better git diff view when `:G d`
# - Some kind of multi-project support (windows? tabs?) and/or "open as project" default
# - Command to edit nix/neovim config
# - rebuild command
# - Restart with the same buffers/state
# - vscode-like runner (run this test/function/etc.)
# - Fix right-click menu
# - v within floaterm uses the floaterm command instead
# - conform-nvim for formatting
# - Better which-key config
# - hover.nvim?
# - Fix neo-tree vs bdelete issue
# - fish completion within floaterm (e.g. % expands to current file)
# - Fix multiline prompt in floaterm
# - ctrl-tab like firefox for buffers
# - ctrl-tab like firefox for jumps
# - Telescope fuzzy finder
# - blink-cmp fix cmdline and disable on treesitter-rename
# - Ctrl-. for common fixes
# - Set up kagi search with avante - https://github.com/yetone/avante.nvim?tab=readme-ov-file#web-search-engines

  programs.nixvim = {
    enable = true;

    defaultEditor = true;

    viAlias = true;
    vimAlias = true;
    vimdiffAlias = true;

    withNodeJs = false;
    withRuby = false;
    withPython3 = true;

    colorschemes.vscode.enable = true;

    lsp = {
      servers = {
        # DevOps
        ansiblels.enable = true;
        bashls.enable = true;
        dockerls.enable = true;
        docker_compose_language_service.enable = true;
        helm_ls.enable = true;
        marksman.enable = true;
        nil_ls.enable = true;
        statix.enable = true;
        terraformls.enable = true;
        tflint.enable = true;

        # Dev
        clangd.enable = true;
        gopls.enable = true;
        ruff.enable = true;
        rust_analyzer.enable = true;

        # Web dev
        astro = {
          enable = true;
          settings.init_options.typescript.tsdk = "${pkgs.typescript}/lib/node_modules/typescript/lib";
        };
        cssls.enable = true;
        html.enable = true;
        tailwindcss.enable = true;
        # superhtml.enable = true;
        eslint.enable = true;
        ts_ls.enable = true;
      };
    };

    plugins = {
      # Git helper
      fugitive.enable = true;
      gitsigns.enable = true;

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
                  if package.loaded["copilot"] == nil then
                    return "";
                  end
                  -- TODO: Check if copilot is actually enabled
                  return " "
                end
              '';
              color.fg = "#ffffff";
            }];
          };
        };
      };
      illuminate.enable = true;
      repeat.enable = true;

      # Editing helpers
      comment = {
        enable = true;
        settings = {
          mappings.extra = false;
          opleader.line = "<C-/>"; # Ctrl-/
          toggler.line = "<C-/>"; # Ctrl-/
        };
      };
      multicursors.enable = true;
      nvim-surround.enable = true;
      guess-indent.enable = true;

      # Documents (markdown)
      markdown-preview.enable = true;
      render-markdown.enable = true;

      # Auto completion
      trouble = {
        # Better code diagnostics
        enable = true;
        settings = {
          auto_close = true;
          auto_preview = true;
          focus = true;
        };
      };
      blink-cmp = {
        enable = true;
        setupLspCapabilities = true;

        settings = {
          keymap = {
            "<Tab>" = [
              { __raw = ''
                function(cmp)
                  -- If Copilot is loaded, accept the suggestion
                  if package.loaded["copilot"] ~= nil and require("copilot.suggestion").is_visible() then
                    require("copilot.suggestion").accept()
                  elseif cmp.snippet_active() then return cmp.accept()
                  else return cmp.select_and_accept()
                  end
                end'';}
              "snippet_forward"
              "fallback"
            ];
            "<S-Tab>" = ["snippet_backward" "fallback"];
            "<CR>" = ["accept" "fallback"];

            "<Up>" = ["select_prev" "fallback"];
            "<Down>" = ["select_next" "fallback"];

            "<C-e>" = ["hide" "fallback"];
            "<C-k>" = ["show_signature" "hide_signature" "fallback"];
            "<C-space>" = ["show" "show_documentation" "fallback"];
          };

          completion = {
            documentation.auto_show = true;
            ghost_text.enabled = true;
          };
          signature.enabled = true;
        };
      };

      rustaceanvim.enable = true;
      lspconfig.enable = true;

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
          ui-select.enable = true;
          undo.enable = true;
        };
      };

      treesitter = {
        enable = true;
        settings = {
          highlight.enable = true;
          indent.enable = true;
          parsers = {
            astro.enable = true;
            bash.enable = true;
            c.enable = true;
            css.enable = true;
            # comment.enable = true;
            fish.enable = true;
            go.enable = true;
            hcl.enable = true;
            html.enable = true;
            hurl.enable = true;
            ini.enable = true;
            javascript.enable = true;
            json.enable = true;
            lua.enable = true;
            nix.enable = true;
            python.enable = true;
            rust.enable = true;
            toml.enable = true;
            typescript.enable = true;
            yaml.enable = true;
          };
        };
      };
      treesitter-refactor = {
        enable = true;
        smartRename = {
          enable = true;
          keymaps.smartRename = "<F2>";
        };
      };

      nvim-autopairs.enable = true;
      copilot-lua = {
        enable = true;

        lazyLoad = {
          enable = true;
          settings = {
            cmd = "Copilot";
            keys = [{
              __unkeyed-1 = "<leader>cc";
              __unkeyed-3 = "<CMD>Copilot enable<CR>";
              desc = "Enable Copilot";
            }];
          };
        };

        settings = {
          suggestion = {
            auto_trigger = true;
            keymap = {
              accept = "<Tab>";
              accept_word = "<C-Right>";
              accept_line = "<C-Down>";
            };
          };
        };
      };

      avante = {
        enable = true;
        lazyLoad = {
          enable = true;
          settings = {
            cmd = "AvanteToggle";
            keys = [
              {
                __unkeyed-1 = "<leader>at";
                __unkeyed-3 = "<CMD>AvanteToggle<CR>";
                desc = "Toggle avante window";
              }
              {
                __unkeyed-1 = "<leader>aa";
                __unkeyed-3 = "<CMD>AvanteShow<CR>";
                desc = "Focus avante window";
              }
            ];
          };
        };
        settings = {
          provider = "copilot";
          disabled_tools = [ "git_commit" ];
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

      floaterm = {
        enable = true;
        settings.keymap_toggle = "<A-Esc>";
      };

      neo-tree = {
        enable = true;
        addBlankLineAtTop = true;
        closeIfLastWindow = true;

        buffers.followCurrentFile.leaveDirsOpen = true;

        filesystem.filteredItems = {
          hideDotfiles = false;
          # hideGitignored = false;
          visible = true;
        };
      };
      which-key.enable = true;

      web-devicons.enable = true; # Telescope & neo-tree dep
      lz-n.enable = true; # Lazy loading
    };

    autoCmd = [
      {
        desc = "Open file at the last position it was edited earlier";
        command = "silent! normal! g`\"zv";
        event = "BufReadPost";
        pattern = "*";
      }
      {
        desc = "Auto-show diagnostics";
        command = "lua vim.diagnostic.open_float()";
        event = "CursorHold";
        pattern = "*";
      }
      {
        desc = "2 space indentation filetypes";
        command = "setlocal ts=2 sts=2 sw=2 expandtab";
        event = "FileType";
        pattern = builtins.concatStringsSep "," ["nix" "hcl" "tf" "yml" "yaml"];
      }
    ];

    diagnostic.settings.signs = {
      text = {
        "__rawKey__vim.diagnostic.severity.ERROR" = "✘";
        "__rawKey__vim.diagnostic.severity.WARN" = "";
        "__rawKey__vim.diagnostic.severity.INFO" = "";
        "__rawKey__vim.diagnostic.severity.HINT" = "󰌵";
      };
    };

    keymaps =
      # Alt-<number> selects buffer number
      (lib.map (n: { key = "<A-${toString n}>"; action = "<CMD>BufferLineGoToBuffer ${toString n}<CR>"; }) (lib.range 1 9)) ++
    [
      # Buffer manipulation
      { key = "<A-c>"; action = "<CMD>bdelete<CR>"; }
      { key = "<A-c>"; action = "<CMD>FloatermKill<CR>"; mode = "t"; }
      { key = "<A-C>"; action = "<CMD>close<CR>"; }
      { key = "<A-o>"; action = "<CMD>only<CR>"; }
      { key = "<A-O>"; action = "<CMD>BufferLineCloseOthers<CR>"; }
      { key = "<A-Left>"; action = "<CMD>BufferLineCyclePrev<CR>"; }
      { key = "<A-Left>"; action = "<CMD>FloatermPrev<CR>"; mode = "t"; }
      { key = "<A-S-Left>"; action = "<CMD>BufferLineMovePrev<CR>"; }
      { key = "<A-Right>"; action = "<CMD>BufferLineCycleNext<CR>"; }
      { key = "<A-Right>"; action = "<CMD>FloatermNext<CR>"; mode = "t"; }
      { key = "<A-S-Right>"; action = "<CMD>BufferLineMoveNext<CR>"; }

      # Window navigation
      { key = "<A-Up>"; action = "<C-W>w"; }
      { key = "<A-Down>"; action = "<C-W>W"; }

      # Split management
      { key = "<A-Return>"; action = "<CMD>vsplit<CR>"; }
      { key = "<A-S-Return>"; action = "<CMD>split<CR>"; }
      { key = "<A-Return>"; action = "<CMD>FloatermNew<CR>"; mode = "t"; }

      # Spell checking toggle
      { key = "<A-s>"; action = "<CMD>set spell!<CR>"; }

      # Disable search highlight
      { key = "<C-l>"; action = "<CMD>nohlsearch<CR>"; }

      # Move a line
      { key = "<C-Up>"; action = "<CMD>move -2<CR>"; }
      { key = "<C-Down>"; action = "<CMD>move +1<CR>"; }

      # Show the filesystem tree
      { key = "<leader>f"; action = "<CMD>Neotree toggle<CR>"; }

      # Show trouble diagnostics
      { key = "<C-.>"; action = "<CMD>Trouble diagnostics toggle<CR>"; }

      # Ctrl-backspace delete word
      { key = "<C-BS>"; action = "<C-w>"; mode = "i"; }
      { key = "<C-BS>"; action = "<C-w>"; mode = "c"; }
      { key = "<C-BS>"; action = "<C-w>"; mode = "t"; }
    ];

    extraPlugins = with pkgs.vimPlugins; [ vim-airline-themes ];

    clipboard = {
      providers.wl-copy.enable = true;
      register = [ "unnamed" "unnamedplus" ];
    };

    globals = {
      # Leader is space
      mapleader = " ";

      # TFLint stuff
      terraform_fmt_on_save = 1;
      terraform_align = 1;
    };

    opts = {
      # Vertical column to avoid ultra long lines
      colorcolumn = "100";
      ruler = true;

      # Line numbers on the side
      number = true;
      relativenumber = true;

      # Highlight the current line
      cursorline = true;

      # Highlight search results
      hlsearch = true;
      # By default ignore the case during search
      ignorecase = true;
      smartcase = true;
      # By default do an incremental search
      incsearch = true;

      # When scrolling, always have 3 lines of buffer
      scrolloff = 3;

      # Tab width shows as 4 characters
      tabstop = 4;

      # Never wrap
      wrap = false;

      # Time to fire the `CursorHold` event
      updatetime = 1500;

      # Show whitespace characters
      list = true;
      listchars = {
        tab = ">_";
        trail = "•";
        extends = "#";
        nbsp = "¶";
      };
    };

    performance = {
      byteCompileLua = {
        enable = true;
        nvimRuntime = true;
        luaLib = true;
        plugins = true;
      };
    };
  };

  stylix.targets.nixvim.enable = false;

  home.sessionVariables = {
    EDITOR = "nvim";
    ALTERNATE_EDITOR = "vim";
  };
}
