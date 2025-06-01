{ pkgs, ... }: {
# Issues:
# - Run python script with args/env (nvim-iron?)
# - Set up nvim-dap
# - Ctrl-backspace deletes the whole word
# - TreeSitter? just better directory listing show? (icons, etc.)
# - Copilot by default? maybe with an alias?
# - Better git diff view when `:G d`
# - Some kind of multi-project support (windows? tabs?) and/or "open as project" default
# - Command to edit nix/neovim config
# - rebuild command
# - Restart with the same buffers/state
# - vscode-like runner (run this test/function/etc.)
# - Fix right-click menu
# - Use lazy loading
# - v within floaterm uses the floaterm command instead
# - conform-nvim for formatting
# - Floaterm-specific Alt-keys (new term, next/prev, etc.)

  programs.nixvim = {
    enable = true;

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
        nixd.enable = true;
        statix.enable = true;
        terraformls.enable = true;

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
        # eslint.enable = true;
        # ts_ls.enable = true;
      };
    };

    plugins = {
      # Sudo helper
      vim-suda.enable = true;

      # Git helper
      fugitive.enable = true;
      gitgutter.enable = true;

      # Buffer view helpers
      bufferline.enable = true;
      lualine = {
        enable = true;
        settings.options.globalstatus = true;
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
      markdown-preview.enable = true;

      # Auto completion
      # trouble.enable = true; # Better code diagnostics
      # fidget = { # Better LSP progress
        # enable = true;
        # settings.progress = {
          # suppress_on_insert = true;
          # ignore_done_already = true;
          # poll_rate = 1;
        # };
      # };
      blink-cmp = {
        enable = true;
        setupLspCapabilities = true;

        settings = {
          # VS-Code like tab completion
          keymap.preset = "enter";

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
          keymaps = {
            "<A-f>" = "find_files";
            "<A-j>" = "lsp_document_symbols";
            "<A-r>" = "command_history";
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
            bash.enable = true;
            c.enable = true;
            go.enable = true;
            hcl.enable = true;
            html.enable = true;
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

      nvim-autopairs.enable = true;
      copilot-lua = {
        enable = false;
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

      neo-tree.enable = true;

      web-devicons.enable = true; # Telescope dep
    };

    keymaps = [
      { key = "<C-Up>"; action = "<CMD>move -2<CR>"; }
      { key = "<C-Down>"; action = "<CMD>move +1<CR>"; }
      { key = "<leader>l"; action = "<CMD>Neotree toggle<CR>"; }
    ];

    extraPlugins = with pkgs.vimPlugins; [ vim-airline-themes ];

    extraConfigVim = builtins.readFile ../system/vimrc;

    viAlias = true;
    vimAlias = true;

    withNodeJs = false;
    withRuby = false;
    withPython3 = true;

    performance = {
      # byteCompileLua = {
      #   enable = true;
      #   nvimRuntime = true;
      #   luaLib = true;
      #   plugins = true;
      # };
    };
  };

  stylix.targets.nixvim = {
    enable = false;
    # transparentBackground.main = true;
    # plugin = "base16-nvim";
  };

  home.sessionVariables = {
    EDITOR = "nvim";
    ALTERNATE_EDITOR = "vim";
  };
                       }
