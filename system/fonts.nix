{ fonts, pkgs, ... }: {
  fonts.packages = with pkgs; [
    iosevka-bin
    nerd-fonts.iosevka
  ];
}
