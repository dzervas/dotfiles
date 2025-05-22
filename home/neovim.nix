{ config, pkgs, ... }: {
# Issues:
# - Run python script with args/env (nvim-iron?)
# - Set up nvim-dap
# - Use nixvim?
# - Move to lua?
# - Change theme
# - Symbol hovering info (like vscode)
# - Fix the fucking == comments
# - Ctrl-backspace deletes the whole word
# - TreeSitter? just better directory listing show? (icons, etc.)
# - Integrated terminal
# - Ctrl-<arrow> to accept only word of copilot suggestion
# - Copilot by default? maybe with an alias?
# - Markdown preview
# - Better git diff view when `:G d`
# - Some kind of multi-project support (windows? tabs?) and/or "open as project" default
# - Command to edit nix/neovim config
# - Better rebuild command
# - Restart with the same buffers/state
# - vscode-like runner (run this test/function/etc.)

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
      cmp = {
        enable = true;
        settings = {
          experimental.ghost_text = true;
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
            { name = "copilot"; }
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
            autoTrigger = true;
            acceptWord = "<C-Right>";
            acceptLine = "<C-Down>";
            acceptWordOrLine = "<C-Right>";
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

    defaultEditor = true;
    viAlias = true;
    vimAlias = true;
    vimdiffAlias = true;

    withNodeJs = false;
    withRuby = false;
    withPython3 = true;

    performance = {

    };

    # plugins = with pkgs.vimPlugins; [
        # vim-move

        # coc-docker
        # coc-json
        # coc-markdownlint
        # coc-toml
        # coc-yaml

# Debugging
        # nvim-dap
        # nvim-dap-lldb
        # nvim-dap-python
        # nvim-dap-rr
        # nvim-dap-ui

# Text objects
        # targets-vim
        # vim-textobj-user
        # vim-textobj-comment
        # vim-textobj-function
# vim-textobj-indent # Doesn't exist
        # ];
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
