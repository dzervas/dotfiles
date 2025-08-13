{ isPrivate, pkgs, ... }: {
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

    (lib.mkIf isPrivate burpsuite-pro)
    (lib.mkIf isPrivate binaryninja)
  ];
}
