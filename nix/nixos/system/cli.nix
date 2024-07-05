{ pkgs, ... }: {
	environment.systemPackages = with pkgs; [
		_7zz
		bat
		colordiff
		fd
		fzf
		git
		lsd
		ripgrep
		vim
		unzip
	];

	# Set fish as the default shell
	programs.fish.enable = true;

	virtualisation.podman.enable = true;
}
