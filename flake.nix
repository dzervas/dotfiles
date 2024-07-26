{
  description = "NixOS configuration flake";

  inputs = {
    nixpkgs.url = "github:nixos/nixpkgs/nixos-unstable";

    agenix.url = "github:ryantm/agenix";
    stylix.url = "github:danth/stylix";

    # Home Manager
    home-manager.url = "github:nix-community/home-manager";
    home-manager.inputs.nixpkgs.follows = "nixpkgs";
    nix-flatpak.url = "github:gmodena/nix-flatpak";

    # ISO generation
    nixos-generators.url = "github:nix-community/nixos-generators";
    nixos-generators.inputs.nixpkgs.follows = "nixpkgs";
  };

  outputs = inputs@{ self, nixpkgs, agenix, stylix, home-manager, nixos-generators, ... }:
    let
      lib = nixpkgs.lib;

      # Function to generate the configuration imports
      mkConfigModules = { hostName, stateVersion, system, isPrivate }: [
        # Set some basic options
        {
          networking.hostName = hostName;
          system.stateVersion = stateVersion;
          home-manager.users.dzervas.home.stateVersion = stateVersion;

          # Allow home-manager to have access to nix-flatpak
          home-manager.extraSpecialArgs = {
            inherit inputs hostName isPrivate;
          };
        }
        {
          options.isPrivate = lib.mkOption {
            type = lib.types.bool;
            default = isPrivate;
          };
        }

        stylix.nixosModules.stylix
        ./configuration.nix
        ./hardware/${hostName}.nix

        home-manager.nixosModules.home-manager
      ];

      # Function to generate a machine configuration
      mkMachine = { hostName, stateVersion, system ? "x86_64-linux" }: let
        # "Private build" mode. If enabled the private nix files will be used.
        # Disabled to be able to build the ISO and initial installation
        isPrivate = if (builtins.pathExists ./home/private/default.nix && hostName != "iso") then
          builtins.trace "🔐 Private submodule build" true
        else
          builtins.trace "📢 Public build" false;
      in {
        nixosConfigurations.${hostName} = lib.nixosSystem {
          inherit system;
          modules = mkConfigModules {
            inherit hostName stateVersion system isPrivate;
          } ++ (if isPrivate then [
            (if isPrivate then agenix.nixosModules.default else {})
            (if isPrivate then { environment.systemPackages = [ agenix.packages.x86_64-linux.default ]; } else {})
          ] else []);
        };
      };
    in
    lib.foldr lib.recursiveUpdate {
      packages.x86_64-linux.iso = nixos-generators.nixosGenerate {
        system = "x86_64-linux";
        format = "install-iso";
        specialArgs = { inherit inputs; };

        modules = [
          # Pin nixpkgs to the flake input, so that the packages installed
          # come from the flake inputs.nixpkgs.url.
          ({ ... }: { nix.registry.nixpkgs.flake = nixpkgs; })
        ] ++ mkConfigModules {
          hostName = "iso";
          stateVersion = "24.11";
        };
      };
    } (map mkMachine [
      { hostName = "laptop"; stateVersion = "23.05"; }
      { hostName = "desktop"; stateVersion = "24.11"; }
    ]);
}
