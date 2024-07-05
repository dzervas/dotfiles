{ pkgs, ... }:

{
	services.flatpak = {
		enable = true;
		update.auto.enable = true;
		uninstallUnmanaged = true;
		packages = [
			"com.spotify.Client"
			"com.slack.Slack"
			"com.discordapp.Discord"
			"com.prusa3d.PrusaSlicer"
			"org.chromium.Chromium"
		];
	};

	xdg.systemDirs.data = [
		"/var/lib/flatpak/exports/share"
		"/home/dzervas/.local/share/flatpak/exports/share"
	];
}
