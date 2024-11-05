{
  description = "NixOS configuration flake";

  inputs = {
    nixpkgs.url = "github:nixos/nixpkgs/nixos-unstable";

    agenix.url = "github:ryantm/agenix";
    lanzaboote.url = "github:nix-community/lanzaboote/v0.4.1";
    lanzaboote.inputs.nixpkgs.follows = "nixpkgs";
    stylix.url = "github:danth/stylix";

    # Home Manager
    home-manager.url = "github:nix-community/home-manager";
    home-manager.inputs.nixpkgs.follows = "nixpkgs";
    flatpak.url = "github:gmodena/nix-flatpak";

    # ISO generation
    nixos-generators.url = "github:nix-community/nixos-generators";
    nixos-generators.inputs.nixpkgs.follows = "nixpkgs";
  };

  outputs = inputs@{ self, nixpkgs, nixos-generators, ... }:
    let
      inherit (nixpkgs) lib;
      utils = import ./utils.nix { inherit inputs lib; };
    in
    lib.foldr lib.recursiveUpdate {
      # The ISO generation module
      packages.x86_64-linux.iso = nixos-generators.nixosGenerate {
        system = "x86_64-linux";
        format = "install-iso";
        specialArgs = { inherit inputs; };

        # Pin nixpkgs to the flake input, so that the packages installed
        # come from the flake inputs.nixpkgs.url.
        modules = [(_: { nix.registry.nixpkgs.flake = nixpkgs; })]
        ++ utils.mkConfigModules {
          system = "x86_64-linux";
          hostName = "iso";
          stateVersion = "24.11";
        };
      };
    } (map utils.mkMachine [
      # Normal machines
      { hostName = "laptop"; stateVersion = "23.05"; }
      { hostName = "desktop"; stateVersion = "24.11"; }
    ]);
}
