# flake.nix specific functions
{ inputs, lib, }: rec {
  # Function to generate a machine configuration
  mkMachine = { hostName, stateVersion, system ? "x86_64-linux" }: let
    # "Private build" mode. If enabled the private nix files will be used.
    # Disabled to be able to build the ISO and initial installation
    isPrivate = builtins.pathExists ./home/private/default.nix && hostName != "iso";
  in {
    nixosConfigurations.${hostName} = lib.nixosSystem {
      inherit system;
      modules = mkConfigModules {
        inherit hostName stateVersion system isPrivate;
      } ++ (if isPrivate then [
        inputs.agenix.nixosModules.default
        { environment.systemPackages = [ inputs.agenix.packages.x86_64-linux.default ]; }
      ] else []);
    };
  };

  # Function to generate the configuration imports
  mkConfigModules = { hostName, stateVersion, system, isPrivate ? false }: [
    # Set some basic options
    {
      networking.hostName = hostName;
      system.stateVersion = stateVersion;
      home-manager.users.dzervas.home.stateVersion = stateVersion;

      # Allow home-manager to have access to nix-flatpak
      home-manager.extraSpecialArgs = {
        inherit hostName isPrivate inputs;
      };
      home-manager.sharedModules = [
        inputs.flatpak.homeManagerModules.nix-flatpak
        (if isPrivate then ./home/private else {})
      ];
    }
    {
      options.isPrivate = lib.mkOption {
        type = lib.types.bool;
        default = isPrivate;
      };
    }

    inputs.stylix.nixosModules.stylix
    ./configuration.nix
    ./hardware/${hostName}.nix

    inputs.home-manager.nixosModules.home-manager

    (if isPrivate then
      builtins.trace "🔐 Private submodule build" {}
    else
      builtins.trace "📢 Public build" {})
  ];
}
