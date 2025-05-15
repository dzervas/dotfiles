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
    hyprland.url = "github:hyprwm/Hyprland";
    hyprland-plugins = {
      url = "github:hyprwm/hyprland-plugins";
      inputs.hyprland.follows = "hyprland";
    };
    rose-pine-hyprcursor = {
      url = "github:ndom91/rose-pine-hyprcursor";
      inputs.nixpkgs.follows = "nixpkgs";
      inputs.hyprlang.follows = "hyprland/hyprlang";
    };

    # KDE
    # plasma-manager = {
      # url = "github:nix-community/plasma-manager/plasma-5";
      # inputs.nixpkgs.follows = "nixpkgs";
      # inputs.home-manager.follows = "home-manager";
    # };

    # ISO generation
    nixos-hardware.url = "github:NixOS/nixos-hardware/master";
  };

  outputs = inputs@{ self, nixpkgs, ... }: let
    inherit (nixpkgs) lib;
    utils = import ./utils.nix { inherit inputs lib; };
  in {
    nixosConfigurations = {
      desktop = utils.mkMachine { hostName = "desktop"; stateVersion = "24.11"; };
      laptop = utils.mkMachine { hostName = "laptop"; stateVersion = "25.05"; };
      iso = nixpkgs.lib.nixosSystem {
        system = "x86_64-linux";
        specialArgs = { inherit inputs; };

        modules = utils.mkConfigModules {
          system = "x86_64-linux";
          hostName = "iso";
          stateVersion = "25.05";
        };
      };
    };
  };
}
