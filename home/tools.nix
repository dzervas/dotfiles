{ pkgs, ... }: {
  home.packages = with pkgs; [
    aircrack-ng
    android-tools
    binwalk sleuthkit
    dirb
    frida-tools
    filezilla
    gobuster
    hashcat
    hashcat-utils
    hcxtools
    hexyl
    iw
    netdiscover
    nmap
    nuclei
    nuclei-templates
    seclists
    sqlmap
    subfinder
    wifite2
    wirelesstools
    wpscan
    xh

    expect # Required by watchf
  ];
}
