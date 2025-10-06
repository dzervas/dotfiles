{ inputs, lib, ... }: let
  inherit (inputs.nixvim.lib.nixvim) utils;
  listAndAttrs = key: cmd: desc: utils.listToUnkeyedAttrs [ key cmd ] // { inherit desc; };
in {
  programs.nixvim = {
    plugins = {
      copilot-lua = {
        enable = true;

        lazyLoad = {
          enable = true;
          settings = {
            cmd = "Copilot";
            keys = [
              (listAndAttrs "<leader>cc" (utils.mkRaw "function() _G.CopilotManager.show_copilot_enable_menu() end") "Enable Copilot (with options)" )
            ];
          };
        };

        settings = {
          suggestion = {
            auto_trigger = false; # Disabled by default, enabled per-project/buffer
            keymap = {
              accept = "<Tab>";
              accept_word = "<C-Right>";
              accept_line = "<C-Down>";
            };
          };
        };
      };

      avante = {
        enable = false;
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
          provider = "copilot";
          disabled_tools = [ "git_commit" ];
          behaviour.auto_approve_tool_permissions = false;
          providers.copilot.model = "claude-sonnet-4";
        };
      };

      opencode = {
        enable = true;
        #lazyLoad = {
        #  enable = true;
        #  settings.keys = [
        #      (listAndAttrs "<leader>aa" (utils.mkRaw "require('opencode').toggle") "Toggle opencode window")
        #      (listAndAttrs "<leader>an" (utils.mkRaw "require('opencode').session_new") "Start a new session")
        #      (listAndAttrs "<leader>aC" (utils.mkRaw "require('opencode').session_compact") "Compact the current session")
        #      (listAndAttrs "<leader>as" (utils.mkRaw "require('opencode').session_interrupt") "Interrupt the current session")
        #    ];
        #};
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
