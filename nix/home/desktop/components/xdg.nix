{ pkgs, ... }: {
	xdg = {
		enable = true;
		mimeApps.enable = true; # Auto-populate default apps
		portal = {
			enable = true;
			# wlr.enable = true;
			xdgOpenUsePortal = true;
			extraPortals = with pkgs; [ xdg-desktop-portal-gtk xdg-desktop-portal-wlr ];
			config = {
				common = {
					# default = ["gtk" "wlr"];
					default = ["wlr"];
					"org.freedesktop.impl.portal.Screencast" = "wlr";
					"org.freedesktop.impl.portal.Screenshot" = "wlr";
				};
			};
		};
		userDirs = {
			enable = true;
			createDirectories = true;
		};
	};
}
