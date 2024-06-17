{ config, pkgs, ... }:

{
	# TODO: All these are user packages
	environment.systemPackages = with pkgs; [
		# swaybg
		# swayidle
		# swaylock
		# i3status
		# dmenu
		# rofi
		waybar
		alacritty
		firefox
		networkmanager
		blueman
		pavucontrol
		grim # screenshot functionality
		slurp # screenshot functionality
		mako # notification system developed by swaywm maintainer
		wl-clipboard # wl-copy and wl-paste for copy/paste from stdin / stdout
		brightnessctl
		playerctl
	];

	services.gnome.gnome-keyring.enable = true;

	programs.sway = {
		enable = true;
		wrapperFeatures.gtk = true;
	};

	# Brightness & volume control
	users.users.dzervas.extraGroups = [ "video" ];
	programs.light.enable = true;
}
