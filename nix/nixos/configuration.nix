{ config, pkgs, lib, ... }:
{
	imports = [ ./system/common.nix ];

	# Bootloader
	# boot.loader.systemd-boot.enable = true;
	# boot.loader.efi.canTouchEfiVariables = true;

	system.stateVersion = "23.05";
	system.copySystemConfiguration = false;

	users.users.dzervas = {
		isNormalUser = true;
		extraGroups = [ "wheel" "video" "uucp" "uinput" ];
		shell = pkgs.fish;
	};

	services.pipewire.enable = true;
	services.fwupd.enable = true;

	# Enable flakes
	nix.settings.experimental-features = [ "nix-command" "flakes" ];
}
