{ pkgs, ... }: {
  stylix = {
    enable = true;
    polarity = "dark";
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
