{ inputs, pkgs, ... }: let
  inherit (inputs.nixvim.lib.nixvim) utils;
in {
  programs.nixvim = {
    lsp.servers = {
      # DevOps
      ansiblels.enable = true;
      bashls.enable = true;
      dockerls.enable = true;
      docker_compose_language_service.enable = true;
      helm_ls.enable = true;
      jsonnet_ls = {
        enable = true;
        config.formatting = {
          PadArrays = true;
          StringStyle = "double";
        };
      };
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
        config.init_options.typescript.tsdk = "${pkgs.typescript}/lib/node_modules/typescript/lib";
      };
      cssls.enable = true;
      html.enable = true;
      tailwindcss.enable = true;
      # superhtml.enable = true;
      eslint.enable = true;
      ts_ls.enable = true;
    };
    plugins = {
      lspconfig.enable = true;

      treesitter = {
        enable = true;

        folding.enable = true;
        settings = {
          highlight = {
            enable = true;
            additional_vim_regex_highlighting = false; # Breaks catppuccin
          };
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

        settings = {
          highlight_current_scope.enable = true;
          highlight_definitions.enable = true;
          smart_rename = {
            enable = true;
            keymaps.smart_rename = "<F2>";
          };
          navigation = {
            enable = true;
            keymaps = {
              goto_definition_lsp_fallback = "<C-]>";
              goto_next_usage = "g<Right>";
              goto_previous_usage = "g<Left>";
              list_definitions = "gl";
            };
          };
        };
      };
      treesitter-context.enable = true;

      inc-rename.enable = true;
    };

    keymaps = [
      { key = "K"; action = utils.mkRaw "vim.lsp.buf.hover"; options.desc = "Show the hover info"; }
      { key = "?"; action = utils.mkRaw "vim.diagnostic.open_float"; options.desc = "Show diagnostic float"; }
      { key = "gr"; action = "<CMD>IncRename<CR>"; options.desc = "Incremental LSP rename"; }
      { key = "gt"; action = utils.mkRaw "function() vim.diagnostic.config({ virtual_text = not vim.diagnostic.config().virtual_text }) end"; options.desc = "Toggle diagnostic virtual_text"; }
      { key = "g<Up>"; action = utils.mkRaw "vim.diagnostic.goto_prev"; options.desc = "Go to previous diagnostic"; }
      { key = "g<Down>"; action = utils.mkRaw "vim.diagnostic.goto_next"; options.desc = "Go to next diagnostic"; }
      { key = "<C-]>"; action = utils.mkRaw "vim.lsp.buf.definition"; options.desc = "Go to definition"; }
      { key = "<C-.>"; action = utils.mkRaw "vim.lsp.buf.code_action"; options.desc = "Code actions menu"; }
      { key = "<leader>w"; action = utils.mkRaw "function () vim.lsp.buf.format({ async = false }) end"; options.desc = "Format the current file";  }
    ];
  };
}
