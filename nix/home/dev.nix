{ pkgs, stylix, ... }:

{
	home.packages = with pkgs; [
		vscode
		nixpkgs-fmt # Used by the Nix IDE extension

		# Languages
		go
		pipenv
		python3
		# python311Packages.ipython
		pyenv
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
