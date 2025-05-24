{ config, pkgs, ... }: {
# Issues:
# - Run python script with args/env (nvim-iron?)
# - Set up nvim-dap
# - Symbol hovering info (like vscode)
# - Ctrl-backspace deletes the whole word
# - TreeSitter? just better directory listing show? (icons, etc.)
# - Integrated terminal
# - Copilot by default? maybe with an alias?
# - Better git diff view when `:G d`
# - Some kind of multi-project support (windows? tabs?) and/or "open as project" default
# - Command to edit nix/neovim config
# - rebuild command
# - Restart with the same buffers/state
# - vscode-like runner (run this test/function/etc.)
# - Fix right-click menu
# - Use lazy loading

  programs.nixvim = {
    enable = true;

    # colorscheme = "vscode";
    colorschemes.vscode.enable = true;

    plugins = {
      # Sudo helper
      vim-suda.enable = true;

      # Git helper
      fugitive.enable = true;
      gitgutter.enable = true;

      # Buffer view helpers
      airline = {
        enable = true;
        settings = {
          theme = "badwolf";
          powerline_fonts = 1;
          highlighting_cache = 1;
          section_y = null; # encoding, file format, etc.
          section_z = null; # position: line no, column, etc.
        };
      };
      illuminate.enable = true;
      repeat.enable = true;

      # Editing helpers
      comment = {
        enable = true;
        settings = {
          toggler = {
            line = "<C-/>";
            # block = "<C-/>"; # TODO: Fix this
          };
          mappings = {
            basic = false;
            extra = false;
          };
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
      # rustaceanvim.enable = true;
      # https://github.com/MikaelFangel/nixvim-config/blob/main/config/cmp.nix
      cmp = {
        enable = true;
        settings = {
          # experimental.ghost_text = true;
          mapping = {
            "<C-Space>" = "cmp.mapping.complete()";
            "<C-d>" = "cmp.mapping.scroll_docs(-4)";
            "<C-e>" = "cmp.mapping.close()";
            "<C-f>" = "cmp.mapping.scroll_docs(4)";
            "<CR>" = "cmp.mapping.confirm({ select = true })";
            "<S-Tab>" = "cmp.mapping(cmp.mapping.select_prev_item(), {'i', 's'})";
            "<Tab>" = "cmp.mapping(cmp.mapping.select_next_item(), {'i', 's'})";
          };
          completion = {
            completeopt = "menu,menuone,noinsert,noselect";
          };
          sources = [
            { name = "nvim_lsp"; }
            { name = "treesitter"; }
            {
              name = "buffer";
              option.get_bufnrs.__raw = "vim.api.nvim_list_bufs";
            }
            { name = "nvim_lua"; }
            { name = "path"; }
            # { name = "copilot"; }
          ];
        };
      };

      lsp = {
        enable = true;
        servers = {
          # DevOps
          bashls.enable = true;
          marksman.enable = true;
          nixd.enable = true;
          terraformls.enable = true;

          # Dev
          clangd.enable = true;
          gopls.enable = true;
          ruff.enable = true;
          rust_analyzer = {
            enable = true;
            installCargo = false;
            installRustc = false;
          };
          ts_ls.enable = true;
        };
      };

      telescope = {
        enable = true;
          keymaps = {
            "<A-f>" = "find_files";
            "<C-F>" = "live_grep";
            "<A-r>" = "commands";
            "<A-z>" = "zoxide list";
            "<A-Tab>" = "buffers";
          };

          extensions = {
            fzf-native.enable = true;
            zoxide.enable = true;
            ui-select.enable = true;
          };
      };

      treesitter = {
        enable = true;
        settings = {
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
        enable = true;
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

      web-devicons.enable = true; # Telescope dep
    };

    keymaps = [
      { key = "<C-Up>"; action = "<CMD>move +1<CR>"; }
      { key = "<C-Down>"; action = "<CMD>move -1<CR>"; }
    ];

    extraPlugins = with pkgs.vimPlugins; [ vim-airline-themes ];

    extraConfigVim = builtins.readFile ../system/vimrc;

    viAlias = true;
    vimAlias = true;

    withNodeJs = false;
    withRuby = false;
    withPython3 = true;

    performance = {
      byteCompileLua = {
        enable = true;
        nvimRuntime = true;
        luaLib = true;
        plugins = true;
      };
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
