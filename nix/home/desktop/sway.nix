{
	config,
	lib,
	pkgs,
	...
}: {
	imports = [ ./components/waybar.nix ];

	services.swaync.enable = true;

	home.packages = with pkgs; [
		# swaybg
		# swayidle
		swaylock
		# i3status
		# dmenu
		# rofi
		# alacritty
		# firefox
		# networkmanager
		# blueman
		# pavucontrol
		wofi
		grim # screenshot functionality
		slurp # screenshot functionality
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
			terminal = "alacritty";
			fonts = lib.mkForce {
				names = [ "Iosevka" ];
				size = 0.5;
			};
			startup = [
				{ command = "alacritty"; }
				{ command = "blueman-applet"; }
			];
			bars = [{
				position = "top";
				command = "waybar";
			}];
			menu = "wofi --show drun";
			input = {
				"type:keyboard" = {
					xkb_layout = "us,gr";
					xkb_options = "grp:alt_space_toggle,caps:escape";
					repeat_rate = "56";
					repeat_delay = "200";
					xkb_capslock = "disabled";
					xkb_numlock = "disabled";
				};
      };

			# Key bindings
			modifier = "Mod4";
			floating.modifier = modifier;
			keybindings = {
				# Basic actions
				"${modifier}+c" = "kill";
				"${modifier}+f" = "fullscreen";
				"${modifier}+z" = "scratchpad show";
				"${modifier}+Down" = "focus left";
				"${modifier}+Up" = "focus right";
				"${modifier}+Shift+f" = "floating toggle";
				"${modifier}+Shift+r" = "reload";
				"${modifier}+Shift+z" = "move scratchpad";
				"${modifier}+Shift+Up" = "move right";
				"${modifier}+Shift+Down" = "move left";
				"${modifier}+Shift+Left" = "move container to workspace left";
				"${modifier}+Shift+Right" = "move container to workspace right";

				# Layout
				"${modifier}+h" = "split h";
				"${modifier}+v" = "split v";
				"${modifier}+e" = "layout toggle split";
				"${modifier}+s" = "layout stacking";
				"${modifier}+t" = "layout tabbed";

				# Core applications
				"${modifier}+Return" = "exec ${terminal}";
				"${modifier}+l" = "exec swaylock";
				"${modifier}+p" = "exec 1password --quick-access";
				"${modifier}+r" = "exec ${menu}";

				# Switch to workspace
				"${modifier}+Left" = "workspace prev_on_output";
				"${modifier}+Right" = "workspace next_on_output";
				"${modifier}+Tab" = "workspace back_and_forth";

				"${modifier}+comma" = "focus output left";
				"${modifier}+period" = "focus output right";

				"${modifier}+1" = "workspace number 1";
				"${modifier}+2" = "workspace number 2";
				"${modifier}+3" = "workspace number 3";
				"${modifier}+4" = "workspace number 4";
				"${modifier}+5" = "workspace number 5";
				"${modifier}+6" = "workspace number 6";
				"${modifier}+7" = "workspace number 7";
				"${modifier}+8" = "workspace number 8";

				# Move focused container to workspace
				"${modifier}+Shift+comma" = "move container to output left";
				"${modifier}+Shift+period" = "move container to output right";
				"${modifier}+Shift+Tab" = "move container to workspace back_and_forth";

				"${modifier}+Shift+1" = "move container to workspace number 1";
				"${modifier}+Shift+2" = "move container to workspace number 2";
				"${modifier}+Shift+3" = "move container to workspace number 3";
				"${modifier}+Shift+4" = "move container to workspace number 4";
				"${modifier}+Shift+5" = "move container to workspace number 5";
				"${modifier}+Shift+6" = "move container to workspace number 6";
				"${modifier}+Shift+7" = "move container to workspace number 7";
				"${modifier}+Shift+8" = "move container to workspace number 8";
			};
		};
		extraConfig = ''
			default_border none
			default_orientation horizontal
			focus_on_window_activation focus
			hide_edge_borders --i3 both
			popup_during_fullscreen smart

			for_window [urgent="latest"] focus
			for_window [class=.*] inhibit_idle fullscreen

			for_window [app_id="(?i)(?:blueman-manager|azote|gnome-disks)"] floating enable
			for_window [app_id="(?i)(?:pavucontrol|nm-connection-editor|gsimplecal|galculator)"] floating enable
			for_window [app_id="(?i)(?:firefox|chromium)"] border none
			for_window [title="(?i)(?:copying|deleting|moving)"] floating enable

			for_window [app_id="^zenity$"] floating enable
			for_window [app_id="^[Pp]inentry-.*"] floating enable
			for_window [app_id="^com-install4j-runtime-launcher-UnixLauncher$"] floating enable
			for_window [app_id="^net-portswigger-burp-browser-BurpBrowserServer$"] floating enable
			for_window [app_id="^burp-StartBurp$"] floating enable
			for_window [app_id="^[Xx]fce4-appfinder$"] floating enable
			for_window [app_id="^torbrowser-launcher$"] floating enable
			for_window [app_id="^1[Pp]assword$"] floating enable
			for_window [app_id="^org.kde.krunner$"] floating enable; move position 35ppt 0; focus
			for_window [title="^Wine System Tray$"] floating enable; move scratchpad
		'';
	};
}
