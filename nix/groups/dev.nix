{ pkgs, ... }:

{
	environment.systemPackages = with pkgs; [
		vscode

		# Languages
		go
		pipenv
		python3
		rustup

		# Cloud stuff
		kubectl
		kubectx
		oci-cli
		terraform
	];
}
