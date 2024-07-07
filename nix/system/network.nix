{ ... }: {
	networking.networkmanager.enable = true;
	# networking.wireless.enable = false; # Can't use with networkmanager???

	# Firewall
	networking.firewall.enable = true;
	networking.firewall.allowedTCPPorts = [ 8181 ];

	programs.nm-applet.enable = true;

	time.timeZone = "Europe/Athens";
}
