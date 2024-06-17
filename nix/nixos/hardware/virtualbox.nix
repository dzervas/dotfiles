{ config, pkgs, lib, ... }:

{
	services.xserver.desktopManager.plasma5.enable = lib.mkForce false;
	services.displayManager.sddm.enable = lib.mkForce false;
	users.users.dzervas.extraGroups = [ "vboxsf" ];
}
