{ inputs, pkgs, ... }: let
  pkgs-master = import inputs.nixpkgs-master {
    inherit (pkgs) system;
    config.allowUnfree = true;
  };
in {
  home.packages = with pkgs; [
    aircrack-ng
    dirb
    pkgs-master.frida-tools
    gobuster
    hashcat
    hashcat-utils
    hcxtools
    iw
    netdiscover
    jadx
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
