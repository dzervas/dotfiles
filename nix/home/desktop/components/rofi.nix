{ config, lib, pkgs, ... }: {
	programs.rofi = {
		enable = true;
		location = "top";
		package = pkgs.rofi-wayland;
		# plugins = with pkgs; [
			# rofi-calc
		# ];

		extraConfig = rec {
			# TODO: Fix calc
			modes = "drun,filebrowser,power-menu,run";
			combi-modes = modes;
			modi = "combi";
			show-icons = true;
			hover-select = true;
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

	home.packages = with pkgs; [
		rofi-power-menu
	];

	programs.waybar.settings.mainBar = lib.mkIf config.programs.waybar.enable {
		"custom/power".on-click = "rofi -no-fixed-num-lines -location 1 -theme-str 'window {width: 10%;}' -show menu -modi 'menu:rofi-power-menu --choices=suspend/shutdown/reboot'";
	};
}
