{ pkgs, ... }:

{
	# TODO: install as user
	services.flatpak.enable = true;

	# Flatpak applications with restricted permissions
	environment.etc."flatpak/installations.d/default.conf".text = ''
		[Installation "default"]
		Path=/var/lib/flatpak
		DisplayName=Default System Installation
		StorageType=Harddisk
		Permissions=restrictive
	'';

	system.activationScripts.installFlatpakApps = {
		text = ''
		flatpak remote-add --if-not-exists flathub https://flathub.org/repo/flathub.flatpakrepo
		flatpak install -y flathub com.spotify.Client
		flatpak install -y flathub com.slack.Slack
		flatpak install -y flathub com.discordapp.Discord
		flatpak install -y flathub org.chromium.Chromium
		flatpak install -y flathub org.prusa3d.PrusaSlicer
		'';
	};
}
