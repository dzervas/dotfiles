{
	config,
	lib,
	pkgs,
	...
}: {

	programs.home-manager.enable = true;
	programs.firefox.enable = true;
	programs.alacritty = {
		enable = true;
		settings = {
			font.size = 12;
			font.normal.family = "Iosevka NFM";
		};
	};

	# CLI tools
	# programs.fd.enable = true;
	# programs.jq.enable = true;
	# programs.lsd.enable = true;
	home.packages = with pkgs; [
		kdePackages.filelight
	];

	home.username = "dzervas";
	home.homeDirectory = "/home/dzervas";
	home.stateVersion = "23.05";

}
