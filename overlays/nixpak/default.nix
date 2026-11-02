# NixPak (https://github.com/nixpak/nixpak) for sandboxed packages
nixpak: final: _prev: let
  # TODO: Drop the patch once nixpak#193 is fixed upstream
  src = final.applyPatches {
    name = "nixpak-patched";
    src = nixpak;
    patches = [ ./tui.patch ];
  };
in {
  # Same as nixpak.lib.nixpak, from the patched source
  mkNixPak = import "${src}/modules" {
    inherit (final) lib;
    pkgs = final;
  };
}
