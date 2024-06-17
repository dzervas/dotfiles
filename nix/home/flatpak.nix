{ pkgs, ... }:

{
	services.flatpak.enable = true;
	services.flatpak.update.auto.enable = true;
	services.flatpak.uninstallUnmanaged = true;
	services.flatpak.packages = [
		com.spotify.Client
		com.slack.Slack
		com.discordapp.Discord
		com.prusa3d.PrusaSlicer
		org.chromium.Chromium
	];
}
