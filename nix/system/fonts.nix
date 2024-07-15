{ fonts
, pkgs
, ...
}: {
  fonts.packages = with pkgs; [
    iosevka-bin
    (nerdfonts.override { fonts = [ "Iosevka" ]; })
  ];
}
