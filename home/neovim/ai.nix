{ config, inputs, ... }: let
  inherit (inputs.nixvim.lib.nixvim) utils;
  listAndAttrs = key: cmd: desc: utils.listToUnkeyedAttrs [ key cmd ] // { inherit desc; };
in {
  programs.nixvim = {
    plugins = {
      supermaven = {
        enable = true;
        settings = {

          keymaps = {
            accept = "<C-l>";
            accept_word = "<C-Right>";
            clear_suggestion = "<C-e><C-e>";
          };

          ignore_filetypes = {
            gitcommit = true;
            gitrebase = true;
            help = true;
            markdown = true;
            envrc = true;
            yaml = true;

            sh = utils.mkRaw ''
              function()
                if string.match(vim.fs.basename(vim.api.nvim_buf_get_name(0)), '^%.env.*') then
                  return true
                end
                return false
              end
            '';
          };
        };
      };

      copilot-lua = {
        enable = false;
        settings = {
          filetypes = {
            "." = false;
            gitcommit = false;
            gitrebase = false;
            help = false;
            markdown = false;
            envrc = false;
            yaml = true;

            sh = utils.mkRaw ''
              function()
                if string.match(vim.fs.basename(vim.api.nvim_buf_get_name(0)), '^%.env.*') then
                  return false
                end
                return true
              end
            '';
          };

          suggestion = {
            auto_trigger = true;
            hide_during_completion = false;
            keymap = {
              accept = "<Tab>";
              accept_word = "<C-Right>";
              accept_line = "<C-Down>";

              # Next/prev suggestions (defualt)
              # dismiss = "<C-]>";
              # next = "<M-]>";
              # prev = "<M-[>";
            };
          };
        };
      };

      # Copilot Next Edit Suggestion (NES)
      sidekick.enable = config.programs.nixvim.plugins.copilot-lua.enable;

      # Maybe https://codecompanion.olimorris.dev/ instead?
      avante = {
        enable = true;
        lazyLoad = {
          enable = true;
          settings = {
            cmd = "AvanteToggle";
            keys = [
              (listAndAttrs "<leader>at" "<CMD>AvanteToggle<CR>" "Toggle avante window")
              (listAndAttrs "<leader>aa" "<CMD>AvanteShow<CR>" "Focus avante window")
            ];
          };
        };
        settings = {
          provider = "claude-code";
          # providers.claude-code.model = "claude-sonnet-4.5";
          # providers.copilot.model = "claude-sonnet-4";

          disabled_tools = [ "git_commit" ];
          behaviour.auto_approve_tool_permissions = false;
        };
      };
    };

    keymaps = if config.programs.nixvim.plugins.sidekick.enable then [
      { key = "<leader>cc"; action = utils.mkRaw "function() require('sidekick.cli').toggle({ name = 'claude'}) end"; options.desc = "Toggle claude window"; }
      { key = "<leader>cs"; mode = "n"; action = utils.mkRaw "function() require('sidekick.cli').send({ msg = '{file}'}) end"; options.desc = "Send buffer to claude"; }
      { key = "<leader>cs"; mode = "v"; action = utils.mkRaw "function() require('sidekick.cli').send({ msg = '{selection}'}) end"; options.desc = "Send selection to claude"; }
      { key = "<Tab>"; mode = "n"; action = utils.mkRaw "function() require('sidekick').nes_jump_or_apply() end"; options.desc = "Accept Next Edit Suggestion"; }
    ] else [];
  };
}
