_: {
  programs.nixvim.plugins = {
    neotest = {
      enable = true;

      lazyLoad = {
        enable = true;
        settings = {
          cmd = "Neotest";
          keys = [
            {
              __unkeyed-1 = "<leader>tt";
              __unkeyed-3 = "<CMD>Neotest summary<CR>";
              desc = "Neotest summary toggle";
            }
            {
              __unkeyed-1 = "<leader>tr";
              __unkeyed-3 = "<CMD>Neotest run<CR>";
              desc = "Neotest run all";
            }
          ];
        };
      };

      settings.adapters = [{ __raw = "require('rustaceanvim.neotest')"; }];
      adapters = {
        bash.enable = true;
        python.enable = true;
      };
    };
  };
}
