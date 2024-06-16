{ pkgs, ... }:

{
  environment.systemPackages = with pkgs; [
    frida
    frida-tools
    nmap
    burp-pro
    net-discover
    wifite2
  ];
}
