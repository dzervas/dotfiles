{ inputs, lib, ... }: let
  inherit (inputs.nixvim.lib.nixvim) utils;
  listAndAttrs = key: cmd: desc: utils.listToUnkeyedAttrs [ key cmd ] // { inherit desc; };
in {
  programs.nixvim = {
    plugins = {
      copilot-lua = {
        enable = true;
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
      sidekick.enable = true;

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
          disabled_tools = [ "git_commit" ];
          behaviour.auto_approve_tool_permissions = false;
          providers.claude-code.model = "claude-sonnet-4.5";
          providers.copilot.model = "claude-sonnet-4";
        };
      };
    };

    autoCmd = [
      {
        event = "BufEnter";
        once = true;
        desc = "Try enabling Copilot once per session";
        callback = utils.mkRaw "CopilotManager.copilot_try_load";
      }
      {
        event = "DirChanged";
        desc = "CopilotManager: clear cwd->root cache on :cd";
        callback = utils.mkRaw "function() M._cwd_root_cache = {}; _G.CopilotManager.copilot_try_load(); end";
      }
    ];
    extraConfigLua = lib.mkAfter (builtins.readFile ./copilot-state.lua);
  };
}
