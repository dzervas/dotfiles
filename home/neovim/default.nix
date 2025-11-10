{ inputs, lib, pkgs, ... }: let
  inherit (inputs.nixvim.lib.nixvim) utils;
in {
  # Issues:
  # - Run python script with args/env (nvim-iron?)
  # - vscode-like runner (run this test/function/etc.)
  # - Fix right-click menu
  # - fish completion within terminal (e.g. % expands to current file)
  # - ctrl-tab like firefox for buffers
  # - ctrl-tab like firefox for jumps
  # - Type annotations as end hints (not inlay)
  # - TOML lints
  # - Disable python line too long & fix imports
  # - Rust workflow to disable formatting and better defaults
  # - JJ integration (lualine and maybe :Jj)
  # - todo-comments plugin and snacks integration https://github.com/folke/snacks.nvim/blob/main/docs/picker.md#todo_comments
  # - Mouse front/back navigation
  # - Better Ctrl-O/Ctrl-I navigation (jump list?)
  # - Code-overview thingy, satellite-nvim is fucking everything up
  # - Add debugging commands and simplify workflow - a LOT of work (lualine and overseer config, etc.)
  # - Define what A-c does - if it's not a normal buffers, close the view, if it's a normal buffer, close it with barbar, if it's the last buffer, open the file finder as well
  # - Snacks terminal config (tabs n all) - https://github.com/folke/snacks.nvim/discussions/2268#discussioncomment-14685823
  # - Open links to browser

  imports = [
    ./ai.nix
    ./completion.nix
    ./debug.nix
    ./lint.nix
    ./lsp.nix
    # ./neovide.nix
    ./python.nix
    ./rust.nix
    ./runner.nix
    ./snacks.nix
    ./ui.nix
  ];

  programs.nixvim = {
    enable = true;
    nixpkgs.config.allowUnfree = true;

    defaultEditor = true;

    viAlias = true;
    vimAlias = true;
    vimdiffAlias = true;

    withNodeJs = false;
    withRuby = false;
    withPython3 = true;

    colorschemes.vscode = {
      enable = true;
      settings = {
        transparent = utils.mkRaw "vim.g.neovide == nil";
        italic_comments = true;
        italic_inlayhints = true;
        underline_links = true;
        terminal_colors = true;
      };
    };

    plugins = {
      # Git helper
      gitsigns.enable = true;
      illuminate.enable = true;
      repeat.enable = true;
      fugitive.enable = true;

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
      nvim-autopairs.enable = true;
      nvim-surround.enable = true;
      guess-indent = {
        enable = true;
        settings = {
          auto_cmd = true;
          on_tab_options = {
            expandtab = false;
            tabstop = 4;
            shiftwidth = 4;
          };
        };
      };
      direnv = {
        enable = true;
        settings.direnv_silent_load = 1;
      };
      scope.enable = true; # Scope buffers per-tab

      which-key.enable = true;

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
        callback = utils.mkRaw "function() vim.diagnostic.open_float(nil, {}) end";
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

    diagnostic.settings = {
      signs.text = utils.toRawKeys {
        "vim.diagnostic.severity.ERROR" = "✘";
        "vim.diagnostic.severity.WARN" = "";
        "vim.diagnostic.severity.INFO" = "";
        "vim.diagnostic.severity.HINT" = "󰌵";
      };

      float = {
        focusable = false;
        style = "minimal";
        border = "rounded";
        source = "always";
        header = "";
        prefix = "";
      };

      virtual_text = {
        spacing = 4;
        source = "if_many";
      };

      underline = true;
      update_in_insert = false;
      severity_sort = true;
    };

    keymaps =
      # Alt-<number> selects buffer number
      (lib.map (n: { key = "<A-${toString n}>"; action = "<CMD>BufferGoto ${toString n}<CR>"; options.desc = "Go to buffer ${toString n}"; }) (lib.range 1 9)) ++
      [
        # Buffer manipulation
        { key = "<A-c>"; action = "<CMD>BufferClose<CR>"; options.desc = "Kill buffer"; }
        { key = "<A-C>"; action = "<CMD>close<CR>"; options.desc = "Close window"; }
        { key = "<A-o>"; action = "<CMD>only<CR>"; options.desc = "Close other windows"; }
        { key = "<A-O>"; action = "<CMD>BufferCloseAllButCurrent<CR>"; options.desc = "Kill all other buffers"; }
        { key = "<A-Left>"; action = "<CMD>BufferPrevious<CR>"; options.desc = "Select previous buffer"; }
        { key = "<A-S-Left>"; action = "<CMD>BufferMovePrevious<CR>"; options.desc = "Move buffer to the left"; }
        { key = "<A-Right>"; action = "<CMD>BufferNext<CR>"; options.desc = "Select next buffer"; }
        { key = "<A-S-Right>"; action = "<CMD>BufferMoveNext<CR>"; options.desc = "Move buffer to the right"; }

        # Window navigation
        { key = "<A-Up>"; action = "<C-W>w"; options.desc = "Cycle to the next window"; }
        { key = "<A-Down>"; action = "<C-W>W"; options.desc = "Cycle to the previous window"; }

        # Tab navigation
        { key = "<A-Tab>"; action = "<CMD>tabnext<CR>"; options.desc = "Cycle to the next tab"; }
        { key = "<A-S-Tab>"; action = "<CMD>tabprevious<CR>"; options.desc = "Cycle to the previous tab"; }
        { key = "<C-A-c>"; action = "<CMD>tabclose<CR>"; options.desc = "Close tab"; }

        # Split management
        { key = "<A-Return>"; action = "<CMD>vsplit<CR><C-W>w"; options.desc = "Open a window to the right"; }
        { key = "<A-S-Return>"; action = "<CMD>split<CR><C-W>w"; options.desc = "Open a window to the bottom"; }

        # Spell checking toggle
        { key = "<leader>s"; action = "<CMD>set spell!<CR>"; options.desc = "Toggle spell checking"; }

        # Disable search highlight
        { key = "<C-l>"; action = "<CMD>nohlsearch<CR>"; options.desc = "Stop highlighting search results"; }

        # Move a line
        { key = "<C-Up>"; action = "<CMD>move -2<CR>"; options.desc = "Move the current line up"; }
        { key = "<C-Down>"; action = "<CMD>move +1<CR>"; options.desc = "Move the current line down"; }

        # Ctrl-backspace delete word
        { key = "<C-BS>"; action = "<C-w>"; mode = ["i" "c" "t"]; options.desc = "Delete word backwards"; }
      ];

    # extraPlugins = with pkgs.vimPlugins; [ vim-airline-themes ];
    extraPackagesAfter = with pkgs; [
      # None-ls packages
      gomodifytags
      impl
      yamllint

      ncurses # infocmp bin
    ];

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

      # Default indentation config
      tabstop = 4;
      shiftwidth = 4;
      expandtab = false;

      # Comment formatting
      # For more: https://neovim.io/doc/user/change.html#fo-table
      formatoptions = "tcqjr";

      # Never wrap
      wrap = false;

      # Time to fire the `CursorHold` event
      updatetime = 1500;

      # Default folds
      foldenable = true;
      foldlevelstart = 10;
      # tree-sitter defines the foldmethod

      # Show whitespace characters
      list = true;
      listchars = {
        tab = ">_";
        trail = "•";
        extends = "#";
        nbsp = "¶";
      };
    };

    performance.byteCompileLua = {
      # enable = true;
      # nvimRuntime = true;
      # luaLib = true;
      # plugins = true;
    };


    # Treesitter language injections without Lua: drop query files into runtimepath
    # Transform files in ./queries (e.g. myfile.scm) into attrset entries like:
    # { "queries/myfile/injections.scm".source = ./queries/myfile.scm; }
    extraFiles = let
      # List of files
      files = builtins.attrNames (builtins.readDir ./queries);
    in
      builtins.listToAttrs (
        map (name: let
            match = builtins.match "^([a-z0-9]+)\.scm$" name;
            base = if match == null then name else builtins.elemAt match 0;
          in {
            # Map each file to a name/value list
            name = "after/queries/${base}/injections.scm";
            value.source = ./queries + "/${name}";
          }
        ) files
        # Make that list into an attrset in the form of "<name>" = "<value>" (value has the .source attrset)
      );
  };

  stylix.targets.nixvim.enable = false;

  home.sessionVariables = {
    EDITOR = "nvim";
    ALTERNATE_EDITOR = "vim";
  };
}
