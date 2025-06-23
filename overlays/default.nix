{ isPrivate, lib, ... }: {
  nixpkgs.overlays = [
    (final: prev: {
      binaryninja = prev.callPackage ./binaryninja.nix {};
      opennoodl = prev.callPackage ./opennoodl.nix {};
      buspirate5-firmware = prev.callPackage ./buspirate5-firmware.nix {};
      pico8 = prev.callPackage ./pico8.nix {};
      flameshot = prev.flameshot.overrideAttrs (previousAttrs: {
        cmakeFlags = [
          "-DUSE_WAYLAND_CLIPBOARD=1"
          "-DUSE_WAYLAND_GRIM=1"
        ];
        buildInputs = previousAttrs.buildInputs ++ [ final.libsForQt5.kguiaddons ];
      });
    } // (lib.mkIf isPrivate (import ../home/.private/overlays.nix)))
  ];
}
