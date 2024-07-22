{ pkgs, ... }:

{
  home.packages = with pkgs; [
    dirb
    frida-tools
    gobuster
    hashcat
    hashcat-utils
    hcxtools
    netdiscover
    jadx
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
