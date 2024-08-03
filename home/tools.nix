{ pkgs, ... }:

{
  home.packages = with pkgs; [
    aircrack-ng
    dirb
    frida-tools
    gobuster
    hashcat
    hashcat-utils
    hcxtools
    netdiscover
    # jadx
    nmap
    nuclei
    nuclei-templates
    seclists
    sqlmap
    subfinder
    wifite2
    wpscan
  ];
}
