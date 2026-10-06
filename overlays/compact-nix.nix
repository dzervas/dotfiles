{
  lib,
  nix,
  nixfmt,
  python3,
  writeShellApplication,
  writeText,
}: let
  # The formatter is a single python file in this repo
  compactNixPy = writeText "compact_nix.py" (builtins.readFile ./compact-nix.py);
in writeShellApplication {
  name = "compact-nix";

  # The script spawns nixfmt and nix-instantiate, so they must be on its PATH
  runtimeInputs = [
    nix
    nixfmt
  ];

  text = ''exec ${python3}/bin/python3 ${compactNixPy} "$@"'';

  meta = with lib; {
    description = "Nix formatter: nixfmt followed by a compact-style pass";
    homepage = "https://github.com/NixOS/nixfmt";
    license = licenses.mit;
    mainProgram = "compact-nix";
    platforms = platforms.unix;
  };
}
