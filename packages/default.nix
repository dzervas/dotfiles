{pkgs ? import <nixpkgs> {}, ...}: let
  p = path: pkgs.callPackage path {};
in {
  packages = {
    # estlcam = p ./estlcam.nix;
  };
}
