{ config, inputs, ... }: let
  inherit (inputs.nixvim.lib.nixvim) utils;
in {
  programs.nixvim = {
    plugins = {
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

      supermaven = {
        enable = true;
        settings = {
          keymaps = {
            accept = "<Tab>";
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

      # Maybe https://codecompanion.olimorris.dev/ instead?
      avante = {
        enable = true;
        settings = {
          # provider = "claude-code";
          # provider = "copilot";
          # providers.copilot.model = "claude-sonnet-4.5";

          provider = "zai";
          auto_suggestions_provider = "zai-suggest";

          providers = rec {
            zai = {
              __inherited_from = "openai";
              endpoint = "https://api.z.ai/api/coding/paas/v4";
              model = "GLM-4.6";
              # api_key_name = "cmd:cat ~/.avante_zai_api_key";
            };
            zai-suggest = zai // {
              model = "GLM-4.5-Air";
            };
            # ollama = {
            #   api_key_name = "";
            #   endpoint = "http://localhost:1234";
            #   model = "deepseek-coder-6.7b-instruct";
            #   # endpoint = "http://localhost:11434";
            #   # model = "Malicus7862/deepseekcoder-6.7b-jarvis-gguf";
            #   stream = true;
            #   extra_request_body.options = {
            #     num_ctx = 16384;
            #     temperature = 0;
            #     max_tokens = 1024;
            #   };
            #   is_env_set = utils.mkRaw "function() return true end";
            # };
          };

          disabled_tools = [ "git_commit" ];
          input.provider = "snacks";

          behaviour = {
            auto_suggestions = false;
            auto_approve_tool_permissions = false;
          };

          suggestion = {
            # in ms
            debounce = 250;
            throttle = 500;
          };

          mappings.suggestion = {
            accept = "<Tab>";
            dismiss = "<C-e><C-e>";
          };
        };
      };

      llm = {
        enable = true;
        settings = {
          backend = "openai";
          url = "http://localhost:1234/v1";
          # model = "qwen2.5-coder-3b-instruct";
          model = "starcoder2-3b";
          context_window = 16384;
          enable_suggestions_on_startup = false;
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
