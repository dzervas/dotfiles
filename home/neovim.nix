{ pkgs, ... }: {
  # Issues:
  # - Transparent background
  # - Open to vscode keybind (with confirmation/menu to open the whole dir)
  # - Run python script with args/env (nvim-iron?)
  # - Set up nvim-dap
  # - Use nixvim?
  # - Move to lua?

  programs.neovim = {
    enable = true;

    defaultEditor = true;
    viAlias = true;
    vimAlias = true;
    vimdiffAlias = true;

    withNodeJs = false;
    withRuby = false;
    withPython3 = true;

    plugins = with pkgs.vimPlugins; [
      # Sudo helper
      vim-suda

      # Git helper
      vim-fugitive
      vim-gitgutter

      # Buffer view helpers
      vim-airline
      vim-airline-themes
      vim-illuminate
      vim-repeat

      # Editing helpers
      auto-pairs
      nerdcommenter
      vim-move
      vim-multiple-cursors
      vim-surround

      # Auto completion
      # DevOps
      coc-docker
      coc-json
      coc-markdownlint
      coc-sh
      coc-toml
      coc-yaml
      # Dev
      coc-go
      # coc-lua
      coc-pyright
      coc-rust-analyzer
      # Web
      coc-tsserver
      # coc-css
      # coc-html
      echodoc-vim
      vim-hcl
      vim-vagrant

      # Debugging
      nvim-dap
      nvim-dap-lldb
      nvim-dap-python
      nvim-dap-rr
      nvim-dap-ui

      # Telescope fuzzy finder
      telescope-nvim
      telescope-coc-nvim
      telescope-dap-nvim

      # Nix linter
      statix

      # Text objects
      targets-vim
      vim-textobj-user
      vim-textobj-comment
      vim-textobj-function
      # vim-textobj-indent # Doesn't exist

      # AI
      copilot-vim
    ];

    coc = {
      enable = true;
      settings = {
        coc.preferences = {
          currentFunctionSymbolAutoUpdate = true;
          enableMessageDialog = true;
          # formatOnSave = true;
          watchmanPath = "${pkgs.watchman}/bin/watchman";
        };
        workspace.removeEmptyWorkspaceFolder = true; # Remove workspace folder when no buffer associated
        fileSystemWatch = {
          watchmanPath = "${pkgs.watchman}/bin/watchman";
          ignoredFolders = ["/private/tmp" "/" "$tmpdir" "target" "node_modules"];
        };
        markdownlint.config = {
          line_length = false;
        };
        languageserver = {
          terraform = {
            command = "${pkgs.terraform-lsp}/bin/terraform-lsp";
            filetypes = ["terraform" "hcl"];
            initializationOptions = {};
          };
        };
      };
    };

    extraConfig = builtins.readFile ./neovim.vim;

    extraPackages = with pkgs; [
      rr # For dap-rr
    ];
  };

  stylix.targets.neovim = {
    enable = true;
    transparentBackground.main = true;
    plugin = "base16-nvim";
  };

  home.sessionVariables = {
    EDITOR = "nvim";
    ALTERNATE_EDITOR = "vim";
  };
}
