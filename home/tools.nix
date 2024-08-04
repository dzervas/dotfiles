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
    iw
    netdiscover
    # jadx
    nmap
    nuclei
    nuclei-templates
    seclists
    sqlmap
    subfinder
    wifite2
    wirelesstools
    wireshark
    wpscan
  ];
}
