{ inputs, lib, pkgs, ... }: let
  inherit (inputs.nixvim.lib.nixvim) utils;
  listAndAttrs = key: cmd: desc: utils.listToUnkeyedAttrs [ key cmd ] // { inherit desc; };
in {
  programs.nixvim = {
    plugins = {
      copilot-vim = {
        enable = true;
        settings = {
          filetypes.".envrc" = false;
          node_command = lib.getExe pkgs.nodejs_22;
        };
      };

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
          provider = "copilot";
          disabled_tools = [ "git_commit" ];
          behaviour.auto_approve_tool_permissions = false;
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
