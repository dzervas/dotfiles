{ ... }: {
	nixpkgs.config.allowUnfree = true;

	imports = [
		# ./boot.nix
		./1password.nix
		./bluetooth.nix
		./cli.nix
		./display.nix
		./fonts.nix
		./network.nix
	];

	services.dbus.enable = true;
}