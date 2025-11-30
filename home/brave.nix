{ pkgs, ... }: {
  # Issues:
  # - Can't install extensions defined below - see https://github.com/nix-community/home-manager/issues/2216
  # - Can't define chrome://flags
  # - Can't change settings
  # - Can't define custom search engine (kagi)

  # TODO: Make a new tab page with many things
  programs.chromium = {
    enable = true;
    package = pkgs.brave;
  };
}
