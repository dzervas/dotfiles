{ pkgs, ... }: {
	environment.systemPackages = with pkgs; [
		vim-full
#		(vim-full.customize {
#			 vimrcConfig.customRC = ''
#				${builtins.readFile ./.vimrc}
#			 '';
#		 })
	];
	environment.etc.vimrc.source = ./.vimrc;
}
