{ pkgs, ... }: let
  base16Scheme = { name }: "${pkgs.base16-schemes}/share/themes/${name}.yaml";
in {
  stylix = {
    enable = true;
    polarity = "dark";
    # For more see https://tinted-theming.github.io/base16-gallery/
    # Good themes:
    # - onedark - washed out
    # - ashes - yellow + green?
    # - darcula - green?
    # - papercolor-dark - a bit too dark
    # - darkmoss
    base16Scheme = base16Scheme { name = "snazzy"; };
    image = pkgs.fetchurl {
      # Photo by Dave Hoefler on Unsplash: https://unsplash.com/photos/sunlight-through-trees-hQNY2WP-qY4
      url = "https://unsplash.com/photos/hQNY2WP-qY4/download?ixid=M3wxMjA3fDB8MXxhbGx8fHx8fHx8fHwxNzIwMzUyNTA4fA&force=true";
      sha256 = "sha256-gw+BkfVkuzMEI8ktiLoHiBMupiUS9AoiB+acFTCt36g=";
    };

    fonts = {
      monospace = {
        package = pkgs.iosevka-bin;
        name = "Iosevka";
      };
    };
  };
}
