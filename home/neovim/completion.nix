{ config, inputs, lib, ... }: let
  inherit (inputs.nixvim.lib.nixvim) utils;
in {
  programs.nixvim.plugins = {
    blink-cmp = {
      enable = true;
      setupLspCapabilities = true;

      settings = {
        enabled.__raw = ''
          function()
            local disabled_bts = {
              "prompt",
              "nofile",
            }
            local disabled_fts = {
              "TelescopePrompt",
              "noice",
              "noice_input",
              "markdown",
            }

            return not vim.tbl_contains(disabled_bts, vim.bo.buftype)
              and not vim.tbl_contains(disabled_fts, vim.bo.filetype)
              and vim.b.completion ~= false
          end
        '';
        keymap = {
          "<Tab>" =
            (if config.programs.nixvim.plugins.sidekick.enable then [(utils.mkRaw ''
              function()
                if package.loaded["sidekick"] ~= nil then
                  return require("sidekick").nes_jump_or_apply()
                end
              end
            '')] else []) ++
          [
            (utils.mkRaw ''
              function(cmp)
                if package.loaded["copilot"] ~= nil and require("copilot.suggestion").is_visible() then
                  require("copilot.suggestion").accept()
                elseif package.loaded["supermaven-nvim"] ~= nil and require("supermaven-nvim.completion_preview").has_suggestion() then
                  require("supermaven-nvim.completion_preview").on_accept_suggestion()
                elseif cmp.snippet_active() then return cmp.accept()
                else return cmp.select_and_accept()
                end
              end
            '')
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

        cmdline = {
          completion.menu.auto_show = true;
          keymap = {
            preset = "inherit";
            "<CR>" = false;
          };
        };

        completion = {
          menu.draw.treesitter = ["lsp"];
          documentation.auto_show = true;
          ghost_text.enabled = true;
        };
        signature.enabled = true;
      };
    };
  };
}
