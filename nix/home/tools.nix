{ pkgs, ... }:

{
	home.packages = with pkgs; [
		arp-scan
		burpsuite
		dirb
		frida-tools
		gobuster
		hashcat
		hashcat-utils
		hcxtools
		nmap
		nuclei
		nuclei-templates
		sqlmap
		subfinder
		wifite2
		wpscan
	];
}
