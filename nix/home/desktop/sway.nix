{
	config,
	lib,
	pkgs,
	...
}: {
	imports = [ ./components/waybar.nix ];

	home.packages = with pkgs; [
		# swaybg
		# swayidle
		# swaylock
		# i3status
		# dmenu
		# rofi
		# alacritty
		# kitty
		# firefox
		# networkmanager
		# blueman
		# pavucontrol
		grim # screenshot functionality
		slurp # screenshot functionality
		mako # notification system developed by swaywm maintainer
		wl-clipboard # wl-copy and wl-paste for copy/paste from stdin / stdout
		brightnessctl
		playerctl
	];

	gtk.enable = true;
	services.gnome-keyring.enable = true;

	wayland.windowManager.sway = {
		enable = true;
		wrapperFeatures.gtk = true;
		config = rec {
			modifier = "Mod4";
			terminal = "kitty";
			fonts = lib.mkForce {
				names = [ "Iosevka" ];
				size = 0.5;
			};
			startup = [
				# { command = "firefox"; }
				{ command = "alacritty"; }
				{ command = "kitty"; }
			];
			bars = [{
				position = "top";
				command = "waybar";
			}];
		};
	};
}
