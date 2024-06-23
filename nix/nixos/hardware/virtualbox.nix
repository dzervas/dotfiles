{ config, pkgs, lib, ... }:

{
	services.xserver.videoDrivers = [ "virtualbox" ];

	services.xserver.displayManager.lightdm.enable = false;
	services.xserver.desktopManager.plasma5.enable = lib.mkForce false;

	users.users.dzervas.extraGroups = [ "vboxsf" ];
}
