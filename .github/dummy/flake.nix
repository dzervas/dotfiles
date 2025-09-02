{
  description = "Dummy private flake";

  outputs = _: {
    # The flag your root flake will read
    isPrivate = false;

    # Provide empty/no-op things so attribute lookups are safe
    overlays.default = _final: _prev: { };
    nixosModules.private = { };
    homeModules.private = { };
  };

  inputs.nixpkgs.url = "github:nixos/nixpkgs/nixos-unstable";
}
