{ pkgs, ... }: {
	# To update shortcuts: nix-shell -p desktop-file-utils --run "update-desktop-database -v"
	services.flatpak = {
		enable = true;
		update.auto.enable = true;
		uninstallUnmanaged = true;
		packages = [
			"com.spotify.Client"
			# "com.slack.Slack"
			"com.discordapp.Discord"
			"com.prusa3d.PrusaSlicer"
			"org.chromium.Chromium"
			# "com.valvesoftware.Steam"
		];
	};

	xdg.systemDirs.data = [
		"/var/lib/flatpak/exports/share"
		"/home/dzervas/.local/share/flatpak/exports/share"
	];

	# hardware.pulseaudio.support32Bit = true;
	# hardware.opengl.driSupport32Bit = true;
}
