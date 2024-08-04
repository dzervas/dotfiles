{ pkgs, wrapWine }: let
  version = "12072";
  source = builtins.fetchurl {
    url = "https://www.estlcam.de/downloads/Estlcam_64_${version}.exe";
    sha256 = "1h806nkpgaw8yhahshqfxsb6fjq1n4s08xw1ivf2lcwcdqmwdy9w";
  };
  bin = wrapWine {
    name = "estlcam";
    is64bits = true;
    executable = "$WINEPREFIX/drive_c/Program Files (x86)/Estlcam12/Estlcam12_CAM.exe";

    firstrunScript = "wine ${source}";
    # wineFlags = "";
    tricks = [ "mono" "gecko" ];
  };
in {
  home.packages = [ bin ];
  xdg.desktopEntries."EstlCAM" = {
    name = "EstlCAM";
    # icon = builtins.fetchurl {
    #   url = icon;
    #   sha256 = iconSha256;
    # };
    exec = "${bin}/bin/estlcam";
  };
}
