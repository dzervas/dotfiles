{ pkgs, ... }: {
  home.packages = with pkgs; [
    aircrack-ng
    dirb
    frida-tools
    gobuster
    hashcat
    hashcat-utils
    hcxtools
    hexyl
    iw
    netdiscover
    jadx
    nmap
    nuclei
    nuclei-templates
    rclone
    seclists
    sqlmap
    subfinder
    wifite2
    wirelesstools
    wireshark
    wpscan
  ];
}
