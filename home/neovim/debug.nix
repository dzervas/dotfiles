_: {
  programs.nixvim.plugins = {
    # Debugging
    # TODO: Lazy load
    dap = {
      enable = true;
      # TODO: Signs https://nix-community.github.io/nixvim/search/?option_scope=0&option=plugins.dap.signs.dapBreakpoint.text&query=dap.
      # By catppuccin:
      signs = {
        dapBreakpoint = {
          text = "●";
          texthl = "DapBreakpoint";
        };
        dapBreakpointCondition = {
          text = "●";
          texthl = "DapBreakpointCondition";
        };
        dapLogPoint = {
          text = "◆";
          texthl = "DapLogPoint";
        };
      };
    };
    dap-virtual-text.enable = true;
    dap-ui.enable = true;
    # dap-view.enable = true;
    overseer.enable = true;
  };
}
