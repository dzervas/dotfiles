{ pkgs, ... }: {
  stylix.image = pkgs.fetchurl {
    # Photo by Wren Meinberg on Unsplash: https://unsplash.com/photos/forest-covered-with-fogs-Fs-bcmsV-hA
    url = "https://images.unsplash.com/photo-1524252500348-1bb07b83f3be";
    sha256 = "sha256-3gH1F4MAM2bKhfHWZrEvCasY8T+rQVxWnKBfHmtTOrM=";
  };
}
