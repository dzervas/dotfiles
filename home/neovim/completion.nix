{ inputs, ... }: let
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
          "<Tab>" = [
            # Prefer assistants over completions
            (utils.mkRaw ''
              function()
                -- Apart from copilot, suggestion engines need to get deferred
                -- otherwise they throw a "can't edit buffer" error.
                if package.loaded["sidekick"] ~= nil then
                  return require("sidekick").nes_jump_or_apply()
                elseif package.loaded["copilot"] ~= nil and require("copilot.suggestion").is_visible() then
                  return require("copilot.suggestion").accept()
                elseif package.loaded["supermaven-nvim"] ~= nil and require("supermaven-nvim.completion_preview").has_suggestion() then
                  vim.schedule(require("supermaven-nvim.completion_preview").on_accept_suggestion)
                  return true
                elseif package.loaded["avante"] ~= nil and require("avante.suggestion").is_visible() then
                  local _, _, sg = require("avante").get()
                  vim.schedule(function() sg:accept() end)
                  return true
                elseif package.loaded["llm"] ~= nil and require("llm.completion").suggestion then
                  vim.schedule(require("llm.completion").complete)
                  return true
                elseif package.loaded["minuet"] ~= nil and require("minuet.virtualtext").action.is_visible then
                  vim.schedule(require("minuet.virtualtext").action.accept)
                  return true
                end
              end
            '')
            # Super-Tab preset (https://cmp.saghen.dev/configuration/keymap.html#super-tab)
            (utils.mkRaw ''
              function(cmp)
                if cmp.snippet_active() then return cmp.accept()
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
