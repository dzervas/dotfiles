{
	description = "Home Manager configuration of dzervas";

	inputs = {
		nixpkgs.url = "github:nixos/nixpkgs/nixos-unstable";

		home-manager = {
			url = "github:nix-community/home-manager";
			inputs.nixpkgs.follows = "nixpkgs";
		};

		nix-flatpak.url = "github:gmodena/nix-flatpak";
	};

	outputs = {
		nixpkgs,
		home-manager,
		nix-flatpak,
		...
	}: let
		system = "x86_64-linux";
		pkgs = nixpkgs.legacyPackages.${system};
	in {
		home-manager.backupFileExtension = "hm-backup";
		homeConfigurations.dzervas = home-manager.lib.homeManagerConfiguration {
			inherit pkgs;
			modules = [
				./home.nix
				./dev.nix
				./neovim.nix
				./fish.nix
				./flatpak.nix
				./desktop/sway.nix
				# ./tools.nix

				nix-flatpak.homeManagerModules.nix-flatpak
			];
		};
	};
}
