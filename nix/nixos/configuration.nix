{ config, pkgs, lib, ... }:
{
	nixpkgs.config.allowUnfree = true;

	# Bootloader
	# boot.loader.systemd-boot.enable = true;
	# boot.loader.efi.canTouchEfiVariables = true;

	# Networking
	networking.networkmanager.enable = true;
	networking.wireless.enable = false; # Can't use with networkmanager???
	networking.firewall.allowedTCPPorts = [ 8181 ];
	networking.firewall.enable = true;
	time.timeZone = "Europe/Athens";

	system.stateVersion = "23.05";
	system.copySystemConfiguration = false;

	# Set fish as the default shell
	programs.fish.enable = true;

	users.users.dzervas = {
		isNormalUser = true;
		extraGroups = [ "wheel" "video" "uucp" "uinput" ];
		shell = pkgs.fish;
	};

	services.xserver.enable = lib.mkForce false;
	services.pipewire.enable = true;
	services.fwupd.enable = true;

	hardware.bluetooth.enable = true;

	# xdg.portal.enable = true;

	virtualisation.podman.enable = true;

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

	nix.settings.experimental-features = [ "nix-command" "flakes" ];
}
