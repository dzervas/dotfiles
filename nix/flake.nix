{
	description = "NixOS configuration flake";

	inputs = {
		nixpkgs.url = "github:nixos/nixpkgs/nixos-unstable";

		stylix.url = "github:danth/stylix";

		# Home Manager
		home-manager.url = "github:nix-community/home-manager";
		home-manager.inputs.nixpkgs.follows = "nixpkgs";
		nix-flatpak.url = "github:gmodena/nix-flatpak";
	};

	outputs = inputs@{ self, nixpkgs, stylix, home-manager, ... }: let
		lib = nixpkgs.lib;
		mkMachine = { hostName, arch ? "x86_64-linux" }: {
			nixosConfigurations.${hostName} = lib.nixosSystem {
				system = arch;
				modules = [
					{ networking.hostName = hostName; }
					stylix.nixosModules.stylix
					./configuration.nix
					./hardware/${hostName}.nix

					home-manager.nixosModules.home-manager
					# Allow home-manager to have access to nix-flatpak
					{ home-manager.extraSpecialArgs.flake-inputs = inputs; }
					# nix-flatpak.homeManagerModules.nix-flatpak
				];
			};
		};
	in
		lib.foldr lib.recursiveUpdate {} (map mkMachine [
			{ hostName = "laptop"; }
			{ hostName = "virtualbox"; }
		]);
}
