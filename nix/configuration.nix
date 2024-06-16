{ config, pkgs, ... }:

{
	nixpkgs.config.allowUnfree = true;

	imports = [
		./groups/dev.nix
		./groups/dotfiles.nix
		./groups/tools.nix
		./groups/desktop/sway.nix
		./groups/flatpak.nix
		./system/boot.nix
		./hardware/docker.nix
		# Include machine-specific configuration
		# ./hardware/${config.networking.hostName}.nix
	];

	users.users.dzervas = {
		isNormalUser = true;
		extraGroups = [ "wheel" "video" "uucp" ];
		shell = pkgs.fish;
	};

	system.stateVersion = "23.05";

	# Set fish as the default shell
	programs.fish.enable = true;

	# Clone dotfiles and create symlinks
	# system.activationScripts.dotfiles = {
	# 	text = ''
	# 	if [ ! -d /home/dzervas/dotfiles ]; then
	# 		git clone https://github.com/dzervas/dotfiles /home/dzervas/dotfiles
	# 	fi
	# 	ln -sf /home/dzervas/dotfiles/.vimrc /home/dzervas/.vimrc
	# 	ln -sf /home/dzervas/dotfiles/.config/nvim /home/dzervas/.config/nvim
	# 	ln -sf /home/dzervas/dotfiles/.config/alacritty /home/dzervas/.config/alacritty
	# 	ln -sf /home/dzervas/dotfiles/.config/fish /home/dzervas/.config/fish
	# 	# Add more symlinks as needed
	# 	'';
	# };

	# Additional configurations
	networking.firewall.allowedTCPPorts = [ 8181 ];
	networking.firewall.enable = true;

	time.timeZone = "Europe/Athens";
}
