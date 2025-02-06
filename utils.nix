# flake.nix specific functions
{ inputs, lib, }: rec {
  # Function to generate a machine configuration
  mkMachine = { hostName, stateVersion, system ? "x86_64-linux" }: let
    # "Private build" mode. If enabled the private nix files will be used.
    # Disabled to be able to build the ISO and initial installation
    isPrivate = builtins.pathExists ./home/.private/default.nix && hostName != "iso";
  in {
    nixosConfigurations.${hostName} = lib.nixosSystem {
      inherit system;

      modules = mkConfigModules {
        inherit hostName stateVersion system isPrivate;
      } ++ [
        # Insert the secure boot module only here to avoid breaking the ISO
        inputs.lanzaboote.nixosModules.lanzaboote
      ];
    };
  };

  # Function to generate the configuration imports
  mkConfigModules = { hostName, stateVersion, system, isPrivate ? false }: [
    # Inject the overlays
    ./overlays
    # Set some basic options
    {
      config = {
        networking.hostName = hostName;
        system.stateVersion = stateVersion;

        home-manager = {
          users.dzervas.home.stateVersion = stateVersion;

          # Allow home-manager to have access to nix-flatpak
          extraSpecialArgs = { inherit hostName isPrivate inputs; };
          sharedModules = [
            inputs.flatpak.homeManagerModules.nix-flatpak
            inputs.cosmic-manager.homeManagerModules.cosmic-manager
          ];
        };
      };

      options.isPrivate = lib.mkOption {
        type = lib.types.bool;
        default = isPrivate;
      };
    }

    inputs.opnix.nixosModules.default

    inputs.stylix.nixosModules.stylix
    inputs.nixos-cosmic.nixosModules.default
    ./configuration.nix
    ./hardware/${hostName}.nix

    inputs.home-manager.nixosModules.home-manager

    (if isPrivate then
      builtins.trace "🔐 Private submodule build" ./home/.private
    else
      builtins.trace "📢 Public build" {})
  ];
}
