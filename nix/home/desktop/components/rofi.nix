{ config, lib, pkgs, ... }: {
	programs.rofi = {
		enable = true;
		location = "top";
		plugins = with pkgs; [
			rofi-calc
		];

		extraConfig = rec {
			# TODO: Fix calc
			modes = "drun,calc,filebrowser,run";
			combi-modes = modes;
			modi = "calc";
			show-icons = true;
		};

		yoffset = if config.programs.waybar.enable then
			# Move the rofi window below the bar (waybar)
			config.programs.waybar.settings.mainBar.height + 5
		else 0;
	};

	# TODO: Define the menu decleretively
	# wayland.windowManager.sway.config = lib.mkIf (config.wayland.windowManager.sway.enable) rec {
		# menu = "rofi";
	# };
}
