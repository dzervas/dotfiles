{ inputs, lib, pkgs, ... }: let
  inherit (inputs.nixvim.lib.nixvim) utils;
in {
  # Issues:
  # - Run python script with args/env (nvim-iron?)
  # - vscode-like runner (run this test/function/etc.)
  # - Fix right-click menu
  # - fish completion within floaterm (e.g. % expands to current file)
  # - Fix multiline prompt in floaterm
  # - ctrl-tab like firefox for buffers
  # - ctrl-tab like firefox for jumps
  # - Type annotations as end hints (not inlay)

  imports = [
    ./ai.nix
    ./completion.nix
    ./lint.nix
    ./neovide.nix
    ./python.nix
    ./rust.nix
    ./runner.nix
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

    colorschemes.vscode.enable = true;

    lsp.servers = {
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
      pyright.enable = true;  # Full Python language server
      ruff.enable = true;     # Python linter/formatter

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

    plugins = {
      # Git helper
      gitsigns.enable = true;
      illuminate.enable = true;
      repeat.enable = true;
      neogit = {
        enable = true;
        lazyLoad = {
          enable = true;
          settings = {
            cmd = "Neogit";
            keys = [
              (utils.listToUnkeyedAttrs ["<leader>g" "<CMD>:Neogit cwd=%:p:h<CR>"] // { desc = "Neogit"; })
            ];
          };
        };

        settings.kind = "floating";
      };

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
      direnv.enable = true;
      scope.enable = true; # Scope buffers per-tab

      # Debugging
      # TODO: Lazy load
      dap = {
        enable = true;
        # TODO: Signs https://nix-community.github.io/nixvim/search/?option_scope=0&option=plugins.dap.signs.dapBreakpoint.text&query=dap.
      };
      dap-virtual-text.enable = true;
      dap-ui.enable = true;

      lspconfig.enable = true;

      treesitter = {
        enable = true;

        folding = true;
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
        highlightCurrentScope.enable = true;
        highlightDefinitions.enable = true;
        navigation = {
          enable = true;

          keymaps = {
            gotoDefinitionLspFallback = "<C-]>";
            gotoNextUsage = "g<Down>";
            gotoPreviousUsage = "g<Up>";
            listDefinitions = "gl";
          };
        };
      };
      treesitter-context.enable = true;

      nvim-autopairs.enable = true;

      floaterm = {
        enable = true;
        settings = {
          keymap_toggle = "<A-Esc>";
          opener = "edit"; # Use 'edit' when opening files from floaterm
        };
      };

      neo-tree = {
        enable = true;
        addBlankLineAtTop = true;

        buffers.followCurrentFile.leaveDirsOpen = true;

        filesystem.filteredItems = {
          hideDotfiles = false;
          visible = true;
        };
      };
      which-key.enable = true;

      lz-n.enable = true; # Lazy loading
      nui.enable = true; # Neo-tree
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
        callback = utils.mkRaw "vim.diagnostic.open_float";
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

    diagnostic.settings.signs.text = utils.toRawKeys {
      "vim.diagnostic.severity.ERROR" = "✘";
      "vim.diagnostic.severity.WARN" = "";
      "vim.diagnostic.severity.INFO" = "";
      "vim.diagnostic.severity.HINT" = "󰌵";
    };

    keymaps =
      # Alt-<number> selects buffer number
      (lib.map (n: { key = "<A-${toString n}>"; action = "<CMD>BufferGoto ${toString n}<CR>"; options.desc = "Go to buffer ${toString n}"; }) (lib.range 1 9)) ++
    [
      # Buffer manipulation
      { key = "<A-c>"; action = "<CMD>BufferClose<CR>"; options.desc = "Kill buffer"; }
      { key = "<A-c>"; action = "<CMD>FloatermKill<CR>"; mode = "t"; options.desc = "Kill terminal session"; }
      { key = "<A-C>"; action = "<CMD>close<CR>"; options.desc = "Close window"; }
      { key = "<A-o>"; action = "<CMD>only<CR>"; options.desc = "Close other windows"; }
      { key = "<A-O>"; action = "<CMD>BufferCloseAllButCurrent<CR>"; options.desc = "Kill all other buffers"; }
      { key = "<A-Left>"; action = "<CMD>BufferPrevious<CR>"; options.desc = "Select previous buffer"; }
      { key = "<A-Left>"; action = "<CMD>FloatermPrev<CR>"; mode = "t"; options.desc = "Select previous terminal"; }
      { key = "<A-S-Left>"; action = "<CMD>BufferMovePrevious<CR>"; options.desc = "Move buffer to the left"; }
      { key = "<A-Right>"; action = "<CMD>BufferNext<CR>"; options.desc = "Select next buffer"; }
      { key = "<A-Right>"; action = "<CMD>FloatermNext<CR>"; mode = "t"; options.desc = "Select next terminal"; }
      { key = "<A-S-Right>"; action = "<CMD>BufferMoveNext<CR>"; options.desc = "Move buffer to the right"; }

      # Window navigation
      { key = "<A-Up>"; action = "<C-W>w"; options.desc = "Cycle to the next window"; }
      { key = "<A-Down>"; action = "<C-W>W"; options.desc = "Cycle to the previous window"; }

      # Tab navigation
      { key = "<A-Tab>"; action = "<CMD>tabnext<CR>"; options.desc = "Cycle to the next tab"; }
      { key = "<A-S-Tab>"; action = "<CMD>tabprevious<CR>"; options.desc = "Cycle to the previous tab"; }
      { key = "<C-A-c>"; action = "<CMD>tabclose<CR>"; options.desc = "Cycle to the next tab"; }

      # Split management
      { key = "<A-Return>"; action = "<CMD>vsplit<CR><C-W>w"; options.desc = "Open a window to the right"; }
      { key = "<A-S-Return>"; action = "<CMD>split<CR><C-W>w"; options.desc = "Open a window to the bottom"; }
      { key = "<A-Return>"; action = "<CMD>FloatermNew<CR>"; mode = "t"; options.desc = "Open a new terminal"; }

      # Spell checking toggle
      { key = "<A-s>"; action = "<CMD>set spell!<CR>"; options.desc = "Toggle spell checking"; }

      # Disable search highlight
      { key = "<C-l>"; action = "<CMD>nohlsearch<CR>"; options.desc = "Stop highlighting search results"; }

      # Move a line
      { key = "<C-Up>"; action = "<CMD>move -2<CR>"; options.desc = "Move the current line up"; }
      { key = "<C-Down>"; action = "<CMD>move +1<CR>"; options.desc = "Move the current line down"; }

      # Show the filesystem tree
      { key = "<leader>f"; action = "<CMD>Neotree toggle<CR>"; options.desc = "Toggle the file explorer"; }
      { key = "<leader>F"; action = "<CMD>Neotree reveal<CR>"; options.desc = "Reveal the current file in the explorer"; }

      # LSP navigation and actions
      { key = "K"; action = utils.mkRaw "vim.lsp.buf.hover"; options.desc = "Show the hover info"; }
      { key = "gd"; action = utils.mkRaw "vim.lsp.buf.definition"; options.desc = "Go to definition"; }
      { key = "gD"; action = utils.mkRaw "vim.lsp.buf.declaration"; options.desc = "Go to declaration"; }
      { key = "gi"; action = utils.mkRaw "vim.lsp.buf.implementation"; options.desc = "Go to implementation"; }
      { key = "gr"; action = utils.mkRaw "vim.lsp.buf.references"; options.desc = "Go to references"; }
      { key = "<C-]>"; action = utils.mkRaw "vim.lsp.buf.definition"; options.desc = "Go to definition"; }
      { key = "<C-.>"; action = utils.mkRaw "vim.lsp.buf.code_action"; options.desc = "Code actions menu"; }
      { key = "<leader>m"; action = "<CMD>NoiceAll<CR>"; options.desc = "Show all messages"; }
      { key = "<leader>w"; action = utils.mkRaw "function () vim.lsp.buf.format({ async = false }) end"; options.desc = "Format the current file";  }

      # Ctrl-backspace delete word
      { key = "<C-BS>"; action = "<C-w>"; mode = "i"; options.desc = "Delete word backwards"; }
      { key = "<C-BS>"; action = "<C-w>"; mode = "c"; options.desc = "Delete word backwards"; }
      { key = "<C-BS>"; action = "<C-w>"; mode = "t"; options.desc = "Delete word backwards"; }
    ];

    extraPlugins = with pkgs.vimPlugins; [ vim-airline-themes ]; # satellite-nvim is fucking everything up
    extraPackagesAfter = with pkgs; [
      # None-ls packages
      gomodifytags
      impl
      yamllint
      codespell

      ncurses # infocmp bin
      vimPlugins.vim-floaterm # provides the 'floaterm' helper script on PATH
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
      files = builtins.attrNames (builtins.readDir ./queries);
    in
      builtins.listToAttrs (
        map (name: let
          match = builtins.match "^([a-z0-9]+)\.scm$" name;
          base = if match == null then name else builtins.elemAt match 0;
        in
          {
            name = "queries/${base}/injections.scm";
            value = { source = ./queries + "/${name}"; };
          }
        )
        files);
  };

  stylix.targets.nixvim.enable = false;

  home.sessionVariables = {
    EDITOR = "nvim";
    ALTERNATE_EDITOR = "vim";
  };
}
