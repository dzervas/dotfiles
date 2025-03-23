{ pkgs, ... }: {
  home.packages = with pkgs; [
    aircrack-ng
    android-tools
    binaryninja
    binwalk sleuthkit
    dirb
    frida-tools
    gobuster
    hashcat
    hashcat-utils
    hcxtools
    hexyl
    iw
    netdiscover
    man-pages
    mullvad-vpn
    # mullvad-browser
    nmap
    nuclei
    nuclei-templates
    rclone
    seclists
    sqlmap
    subfinder
    # wifite2
    wirelesstools
    wireshark
    wpscan
  ];
}
