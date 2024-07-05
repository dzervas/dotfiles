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
		unzip
	];

	# Set fish as the default shell
	programs.fish.enable = true;

	virtualisation.podman.enable = true;

	security = {
		pam.services.kwallet = {
			name = "kwallet";
			enableKwallet = true;
		};
	};
}
