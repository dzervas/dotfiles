{ config, pkgs, ... }:

{
	imports = [ <nixpkgs/nixos/modules/installer/virtualbox-demo.nix> ];

	services.xserver.desktopManager.plasma5.enable = lib.mkForce false;
	services.displayManager.sddm.enable = lib.mkForce false;
}
