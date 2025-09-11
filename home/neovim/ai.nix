{ lib, ... }: {
  programs.nixvim = {
    plugins = {
      copilot-lua = {
        enable = true;

        lazyLoad = {
          enable = true;
          settings = {
            cmd = "Copilot";
            keys = [{
              __unkeyed-1 = "<leader>cc";
              __unkeyed-3 = "<CMD>lua _G.CopilotManager.show_copilot_enable_menu()<CR>";
              desc = "Enable Copilot (with options)";
            }];
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
        enable = true;
        lazyLoad = {
          enable = true;
          settings = {
            cmd = "AvanteToggle";
            keys = [
              {
                __unkeyed-1 = "<leader>at";
                __unkeyed-3 = "<CMD>AvanteToggle<CR>";
                desc = "Toggle avante window";
              }
              {
                __unkeyed-1 = "<leader>aa";
                __unkeyed-3 = "<CMD>AvanteShow<CR>";
                desc = "Focus avante window";
              }
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
        callback.__raw = "CopilotManager.copilot_try_load";
      }
      {
        event = "DirChanged";
        desc = "CopilotManager: clear cwd->root cache on :cd";
        callback.__raw = "function() M._cwd_root_cache = {} end";
      }
    ];
    extraConfigLua = lib.mkAfter (builtins.readFile ./copilot-state.lua);
  };
}
