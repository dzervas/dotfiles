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
      url = "https://unsplash.com/photos/WeYamle9fDM/download?ixid=M3wxMjA3fDB8MXxhbGx8fHx8fHx8fHwxNzIwMzAwOTk3fA&force=true";
      sha256 = "sha256-ZPJL1O+80s8tylvQwd9ZrZMJbLgmj0teDjEkqUCZMVU=";
    };

    fonts = {
      monospace = {
        package = pkgs.iosevka-bin;
        name = "Iosevka";
      };
    };
  };
}
