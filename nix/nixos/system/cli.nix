{ pkgs, ... }: {
	environment.systemPackages = with pkgs; [
		bat
		colordiff
		fd
		fzf
		git
		ripgrep
		vim
	];

	# Set fish as the default shell
	programs.fish.enable = true;

	virtualisation.podman.enable = true;
}
