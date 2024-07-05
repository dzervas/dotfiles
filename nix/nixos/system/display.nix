{ lib, pkgs, ... }: {
	services.xserver.enable = true;
	hardware.graphics.enable = true;
	security.polkit.enable = true;
	services.displayManager = {
		autoLogin.enable = lib.mkForce false;
		sddm.enable = true;
		sddm.wayland.enable = true;
	};

	programs.sway = {
		enable = true;
		wrapperFeatures.gtk = true;
	};

	xdg.portal = {
		enable = true;
		wlr.enable = true;
		extraPortals = [ pkgs.xdg-desktop-portal-wlr ];
	};

	# faster sway maybe? https://nixos.wiki/wiki/Sway
	security.pam.loginLimits = [{
		domain = "@users";
		item = "rtprio";
		type = "-";
		value = 1;
	}];

	# Electron fix - https://nixos.wiki/wiki/Wayland#Electron_and_Chromium
	environment.sessionVariables.NIXOS_OZONE_WL = "1";

	# Icon theme
	environment.systemPackages = with pkgs; [
		adwaita-icon-theme
		qt5.qtwayland
	];

	# Brightness control
	programs.light.enable = true;

	services.flatpak.enable = true;
	services.accounts-daemon.enable = true; # Flatpak needs this

	qt = {
		enable = true;
		platformTheme = "gnome";
		style = "adwaita-dark";
	};
}
