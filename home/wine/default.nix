{ pkgs, ... }: let
  wrapWine-src = builtins.fetchurl {
    url = "https://github.com/lucasew/nixcfg/raw/842cbec77d374ceb2b67c70795f7a6f3a99c563d/nix/pkgs/wrapWine.nix";
    sha256 = "1dpfaij8pp176sj0wlvib49i7k8r9msv1cikp28xlxljyk2njam9";
  };
  wrapWine = import wrapWine-src { inherit pkgs; };
in {
  imports = [
    (import ./estlcam.nix { inherit pkgs wrapWine; })
  ];
}
