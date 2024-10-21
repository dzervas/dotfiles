{ inputs, pkgs, ... }: let
  # TODO: Fix this upstream
  pkgs-overlay = import inputs.nixpkgs {
    inherit (pkgs) system;

    overlays = [
      (final: prev: {
        frida-tools = prev.python3Packages.buildPythonApplication (prev.frida-tools // rec {
          version = "13.6.0";
          src = prev.fetchPypi {
            inherit version;
            pname = "frida-tools";
            hash = "sha256-M0S8tZagToIP6Qyr9RWNAGGfWOcOtO0bYKC02IhCpvg=";
          };
        });
      })
    ];
  };
in {
  home.packages = with pkgs; [
    aircrack-ng
    dirb
    pkgs-overlay.frida-tools
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
