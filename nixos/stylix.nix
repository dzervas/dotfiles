{ inputs, lib, pkgs, ... }:
let
  base16Scheme = { name }: "${pkgs.base16-schemes}/share/themes/${name}.yaml";
in
{
  imports = [
    ./nix.nix
  ];

  boot.binfmt.emulatedSystems = [ "aarch64-linux" ];

  stylix = {
    enable = true;
    autoEnable = true;
    polarity = "dark";
    # For more see https://tinted-theming.github.io/base16-gallery/
    base16Scheme = base16Scheme { name = "snazzy"; };
    image = lib.mkDefault pkgs.nixos-artwork.wallpapers.gear.gnomeFilePath;

    cursor = {
      package = inputs.rose-pine-hyprcursor.packages.${pkgs.system}.default;
      name = "BreezX-RosePine-Linux";
      size = 32;
    };

    fonts = {
      monospace = {
        package = pkgs.nerd-fonts.iosevka;
        name = "Iosevka Nerd Font";
      };
      sizes = {
        desktop = 12;
        popups = 14;
        terminal = 14;
      };
    };
  };
}
