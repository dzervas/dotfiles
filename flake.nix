{
  description = "NixOS configuration flake";

  inputs = {
    nixpkgs.url = "github:nixos/nixpkgs/nixos-unstable";

    opnix.url = "github:dzervas/opnix";
    opnix.inputs.nixpkgs.follows = "nixpkgs";

    lanzaboote.url = "github:nix-community/lanzaboote";
    lanzaboote.inputs.nixpkgs.follows = "nixpkgs";
    stylix.url = "github:danth/stylix";

    # Home Manager
    home-manager.url = "github:nix-community/home-manager";
    home-manager.inputs.nixpkgs.follows = "nixpkgs";
    flatpak.url = "github:gmodena/nix-flatpak";

    # Cosmic Desktop
    # nixos-cosmic.url = "github:lilyinstarlight/nixos-cosmic";
    # nixos-cosmic.inputs.nixpkgs.follows = "nixpkgs";
    # cosmic-manager = {
    #   url = "github:HeitorAugustoLN/cosmic-manager";
    #   inputs.nixpkgs.follows = "nixpkgs";
    #   inputs.home-manager.follows = "home-manager";
    # };

    # HyprLand
    # hyprland.url = "github:hyprwm/Hyprland";
    # hyprland-plugins = {
    #   url = "github:hyprwm/hyprland-plugins";
    #   inputs.hyprland.follows = "hyprland";
    # };

    # KDE
    # plasma-manager = {
      # url = "github:nix-community/plasma-manager/plasma-5";
      # inputs.nixpkgs.follows = "nixpkgs";
      # inputs.home-manager.follows = "home-manager";
    # };

    # ISO generation
    nixos-hardware.url = "github:NixOS/nixos-hardware/master";
  };

  outputs = inputs@{ self, nixpkgs, ... }:
    let
      inherit (nixpkgs) lib;
      utils = import ./utils.nix { inherit inputs lib; };
      machines = map utils.mkMachine [
        # Normal machines
        { hostName = "laptop"; stateVersion = "25.05"; }
        { hostName = "desktop"; stateVersion = "24.11"; }
      ];
    # This results in (recursiveUpdate ( recursiveUpdate { <iso> } machines[0] ) machines[1] )
    # The { <iso> } is only passed as a function parameter once, on the first call to recursiveUpdate
    # the rest of the calls are made with the result of the previous call + the next element in the list
    in lib.foldr lib.recursiveUpdate {
      # The ISO generation module
      # For more check https://blog.thomasheartman.com/posts/building-a-custom-nixos-installer
      nixosConfigurations.iso = nixpkgs.lib.nixosSystem {
        system = "x86_64-linux";
        specialArgs = { inherit inputs; };

        modules = utils.mkConfigModules {
          system = "x86_64-linux";
          hostName = "iso";
          stateVersion = "25.05";
        };
      };
    } machines;
}
