{ pkgs, ... }: {
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
			# Git helper
			vim-gitgutter

			# Buffer view helpers
			vim-airline
			vim-airline-themes
			vim-illuminate
			vim-repeat

			# THE theme
			molokai

			# Editing helpers
			auto-pairs
			nerdcommenter
			vim-move
			vim-multiple-cursors
			vim-surround

			# Auto completion
			deoplete-clang
			deoplete-fish
			deoplete-go
			deoplete-jedi
			deoplete-nvim
			deoplete-rust
			echodoc-vim

			# Text objects
			targets-vim
			vim-textobj-user
				vim-textobj-comment
				vim-textobj-function
				# vim-textobj-indent # Doesn't exist
		];
	};
}
