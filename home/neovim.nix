{ pkgs, ... }: {
  # Issues:
  # - Comments get un-indented
  # - Copilot? (only when hitting a specific keybind)
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
      deoplete-clang
      deoplete-fish
      # deoplete-go
      deoplete-jedi
      deoplete-nvim
      deoplete-rust
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
    ];

    extraPython3Packages = p: with p; [ jedi ];
    extraConfig = ''
      source /etc/vimrc
      set viminfo&

      " Airline
      let g:airline_powerline_fonts = 1
      let g:airline_theme = "badwolf"
      let g:airline#extensions#syntastic#enabled = 1
      let g:airline#extensions#hunks#non_zero_only = 0

      " Nerd Commenter
      let g:NERDSpaceDelims = 1
      let g:NERDTrimTrailingWhitespace = 1
      nmap <C-/> <Plug>NERDCommenterToggle
      vmap <C-/> <Plug>NERDCommenterToggle<CR>gv

      " Deoplete
      let g:deoplete#enable_at_startup = 1
      let g:deoplete#sources#clang#libclang_path = "${pkgs.libclang}/lib"
      let g:echodoc_enable_at_startup = 1
      let g:jedi#show_docstring = 1
      let g:jedi#show_call_signatures = 2
      let g:jedi#popup_select_first = 0
      call deoplete#custom#option('smart_case', v:true)
      call deoplete#custom#source('_', 'converters', ['converter_auto_paren', 'converter_auto_delimiter'])
      autocmd InsertLeave * if !pumvisible() | pclose | endif

      " Move
      let g:move_map_keys = 0
      nmap <C-up>   <Plug>MoveLineUp
      nmap <C-down> <Plug>MoveLineDown
      vmap <C-up>   <Plug>MoveBlockUp
      vmap <C-down> <Plug>MoveBlockDown

      " Automatically open a file with sudo
      let g:suda_smart_edit = 1
      cnoremap e! SudaRead
      cnoremap w! SudaWrite

      " Terminal stuff
      autocmd TermOpen * startinsert
      autocmd FileType nix noremap <leader>r <cmd>belowright 10split term://rebuild<cr>
      noremap <A-R> <cmd>source ~/.config/nvim/init.lua<cr>
    '';
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
