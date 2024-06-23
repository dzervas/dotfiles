{ config, pkgs, ... }:

{
	# TODO: All these are user packages
	home.packages = with pkgs; [
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

	services.gnome-keyring.enable = true;

	wayland.windowManager.sway = {
		enable = true;
		wrapperFeatures.gtk = true;
		config = rec {
			modifier = "Mod4";
			terminal = "alacritty";
		};
	};
}
