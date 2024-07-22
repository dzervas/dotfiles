{ lib, pkgs, ... }:
let
  base16Scheme = { name }: "${pkgs.base16-schemes}/share/themes/${name}.yaml";
in
{
  stylix = {
    enable = true;
    polarity = "dark";
    # For more see https://tinted-theming.github.io/base16-gallery/
    base16Scheme = base16Scheme { name = "snazzy"; };
    image = lib.mkDefault pkgs.nixos-artwork.wallpapers.gear.gnomeFilePath;

    fonts = {
      monospace = {
        package = pkgs.iosevka-bin;
        name = "Iosevka";
      };
      sizes.desktop = 12;
      sizes.popups = 14;
    };
  };
}
