_: {
  nixpkgs.overlays = [
    (_final: prev: {
      cursor-cli = prev.callPackage ./cursor-cli.nix {};
      opennoodl = prev.callPackage ./opennoodl.nix {};
      buspirate5-firmware = prev.callPackage ./buspirate5-firmware.nix {};
    })
  ];
}
