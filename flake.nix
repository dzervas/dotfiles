{
  description = "NixOS configuration flake";

  inputs = {
    nixpkgs.url = "github:nixos/nixpkgs/nixos-unstable";
    home-manager.url = "github:nix-community/home-manager";
    home-manager.inputs.nixpkgs.follows = "nixpkgs";

    # ISO generation & laptop stuff
    nixos-hardware.url = "github:NixOS/nixos-hardware/master";

    # 1Password secrets
    opnix.url = "github:dzervas/opnix";
    opnix.inputs.nixpkgs.follows = "nixpkgs";

    # Secure boot
    lanzaboote.url = "github:nix-community/lanzaboote";
    lanzaboote.inputs.nixpkgs.follows = "nixpkgs";

    # Home stuff
    stylix.url = "github:danth/stylix";
    flatpak.url = "github:gmodena/nix-flatpak";
    nixvim.url = "github:nix-community/nixvim";
    # nixvim.follows = "nixpkgs";

    # HyprLand
    hyprland.url = "github:hyprwm/Hyprland";
    hyprland-plugins.url = "github:hyprwm/hyprland-plugins";
    hyprland-plugins.inputs.hyprland.follows = "hyprland";

    rose-pine-hyprcursor = {
      url = "github:ndom91/rose-pine-hyprcursor";
      inputs.nixpkgs.follows = "nixpkgs";
      inputs.hyprlang.follows = "hyprland/hyprlang";
    };

    # Cosmic Desktop
    # nixos-cosmic.url = "github:lilyinstarlight/nixos-cosmic";
    # nixos-cosmic.inputs.nixpkgs.follows = "nixpkgs";
    # cosmic-manager = {
    #   url = "github:HeitorAugustoLN/cosmic-manager";
    #   inputs.nixpkgs.follows = "nixpkgs";
    #   inputs.home-manager.follows = "home-manager";
    # };

    # KDE
    # plasma-manager = {
      # url = "github:nix-community/plasma-manager/plasma-5";
      # inputs.nixpkgs.follows = "nixpkgs";
      # inputs.home-manager.follows = "home-manager";
    # };
  };

  outputs = inputs@{ self, nixpkgs, ... }: let
    inherit (nixpkgs) lib;

    # "Private build" mode. If enabled the private nix files will be used.
    # Disabled to be able to build the ISO and initial installation
    isPrivate = builtins.pathExists ./home/.private/default.nix;
    desktop = "hyprland";

    inherit (import ./mkMachine.nix { inherit inputs lib desktop; }) mkMachine;
  in {
    nixosConfigurations = {
      desktop = mkMachine { inherit isPrivate; hostName = "desktop"; stateVersion = "24.11"; };
      laptop = mkMachine { inherit isPrivate; hostName = "laptop"; stateVersion = "25.05"; };
      iso = mkMachine { isPrivate = false; hostName = "iso"; stateVersion = "25.05"; };
    };
  };
}
