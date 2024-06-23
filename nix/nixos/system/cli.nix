{ pkgs, ... }: {
	environment.systemPackages = with pkgs; [
		bat
		colordiff
		ripgrep
		fd
		fzf
		vim
		fish
	];

	# Set fish as the default shell
	programs.fish.enable = true;

	virtualisation.podman.enable = true;
}
