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
			"md.obsidian.Obsidian"
		];

		overrides = {
			global.Environment.GTK_THEME = "Adwaita:dark";
			"com.prusa3d.PrusaSlicer".Context.sockets = ["x11" "fallback-x11"];
		};
	};
}
