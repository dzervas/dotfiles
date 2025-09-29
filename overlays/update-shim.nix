{ system ? builtins.currentSystem }: import <nixpkgs> {
  inherit system;
  overlays = [ (import ./packages.nix) ];
}
