{
	description = "Home Manager configuration of dzervas";

	inputs = {
		nixpkgs.url = "github:nixos/nixpkgs/nixos-unstable";

		home-manager = {
			url = "github:nix-community/home-manager";
			inputs.nixpkgs.follows = "nixpkgs";
		};

		catppuccin.url = "github:catppuccin/nix";
		nix-flatpak.url = "github:gmodena/nix-flatpak";
	};

	outputs = {
		nixpkgs,
		home-manager,
		nix-flatpak,
		catppuccin,
		...
	}: let
		system = "x86_64-linux";
		pkgs = nixpkgs.legacyPackages.${system};
	in {
		home-manager.backupFileExtension = "hm-backup";
		homeConfigurations.dzervas = home-manager.lib.homeManagerConfiguration {
			inherit pkgs;
			modules = [
				{ nixpkgs.config.allowUnfree = true; }
				./1password.nix
				./home.nix
				./dev.nix
				./git.nix
				./ssh.nix
				./neovim.nix
				./fish.nix
				./flatpak.nix
				./desktop/sway.nix
				./theme.nix
				# ./tools.nix

				nix-flatpak.homeManagerModules.nix-flatpak
				catppuccin.homeManagerModules.catppuccin
			];
		};
	};
}
