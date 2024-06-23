{ config, pkgs, lib, ... }:

{
	# Needs 3D acceleration enabled with VMSVGA controller
	services.xserver.displayManager.lightdm.enable = false;
	services.xserver.desktopManager.plasma5.enable = lib.mkForce false;

	users.users.dzervas.extraGroups = [ "vboxsf" ];
}
