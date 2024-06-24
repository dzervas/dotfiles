{
	config,
	lib,
	pkgs,
	...
}: {
	nixpkgs.config.allowUnfree = true;

	programs.home-manager.enable = true;
	programs.firefox.enable = true;
	programs.alacritty.enable = true;

	home.username = "dzervas";
	home.homeDirectory = "/home/dzervas";
	home.stateVersion = "23.05";
}
