{ pkgs, stylix, ... }:

{
	home.packages = with pkgs; [
		vscode
		nixpkgs-fmt # Used by the Nix IDE extension

		# Languages
		go
		pipenv
		python3
		rustup
		pnpm
		nodejs

		# Cloud stuff
		kubectl
		kubectx
		oci-cli
		terraform
	];
}
