{ config, pkgs, lib, ... }:
{
	imports = [ ./system/common.nix ];

	system.copySystemConfiguration = false;

	users.users.dzervas = {
		isNormalUser = true;
		extraGroups = [ "wheel" "audio" "video" "uucp" "uinput" ];
		shell = pkgs.fish;
	};

	home-manager = {
		useGlobalPkgs = true;
		useUserPackages = true;
		users.dzervas = import ./home/home.nix;
	};

	services.pipewire = {
		enable = true;
		pulse.enable = true;
		wireplumber.enable = true;
	};
	services.fwupd.enable = true;

	# Enable flakes
	nix.settings.experimental-features = [ "nix-command" "flakes" ];

	# Fix flatpak default browser
	systemd.user.extraConfig = "DefaultEnvironment=\"PATH=/run/current-system/sw/bin\"";
}
