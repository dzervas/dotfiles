{ pkgs, ... }: {
  # Issues:
  # - Comments get un-indented
  # - Move to a better language server?
  # - More intuitive git controls (stage/unstage block)
  # - Automatically UpdateRemotePlugins
  # - Transparent background
  # - Open to vscode keybind (with confirmation/menu to open the whole dir)
  # - Run python script with args/env

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
      settings = {};
    };

    extraPython3Packages = p: with p; [ jedi ];
    extraConfig = builtins.readFile ./neovim.vim;
  };

  stylix.targets.nixvim = {
    enable = true;
    transparentBackground.main = true;
    plugin = "base16-nvim";
  };

  home.sessionVariables = {
    EDITOR = "nvim";
    ALTERNATE_EDITOR = "vim";
  };
}
