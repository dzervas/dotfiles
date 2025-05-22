_: {
  nixpkgs.overlays = [
    (final: prev: {
      # atuin-desktop = prev.callPackage ./atuin-desktop.nix {};
      binaryninja = prev.callPackage ./binaryninja.nix {};
      opennoodl = prev.callPackage ./opennoodl.nix {};
      buspirate5-firmware = prev.callPackage ./buspirate5-firmware.nix {};
      flameshot = prev.flameshot.overrideAttrs (previousAttrs: {
        cmakeFlags = [
          "-DUSE_WAYLAND_CLIPBOARD=1"
          "-DUSE_WAYLAND_GRIM=1"
        ];
        buildInputs = previousAttrs.buildInputs ++ [ final.libsForQt5.kguiaddons ];
      });
    })
  ];
}
