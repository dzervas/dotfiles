{
	description = "NixOS configuration flake";

	# inputs.nixpkgs.url = "github:nixos/nixpkgs/nixos-unstable";

	outputs = { self, nixpkgs, ... }: {
		nixosConfigurations = {
			"virtualbox" = nixpkgs.lib.nixosSystem {
				system = "x86_64-linux";
				modules = [
					# (nixpkgs + "/nixos/modules/installer/cd-dvd/installation-cd-minimal.nix")
					(nixpkgs + "/nixos/modules/installer/virtualbox-demo.nix")
					./configuration.nix
					./hardware/virtualbox.nix
				];
			};
		};
	};
}
