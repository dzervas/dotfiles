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
