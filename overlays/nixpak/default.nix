# NixPak (https://github.com/nixpak/nixpak) for sandboxed packages
nixpak: final: _prev: {
  # Same as nixpak.lib.nixpak
  mkNixPak = import "${nixpak}/modules" {
    inherit (final) lib;
    pkgs = final;
  };
}
