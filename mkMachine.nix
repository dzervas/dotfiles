# flake.nix specific functions
{ desktop, inputs, nixpkgs, lib }: {
  # Function to generate a machine configuration
  mkMachine = {
    hostName,
    stateVersion,
    isPrivate,
    system ? "x86_64-linux",
  }: lib.nixosSystem {
    inherit system;

    specialArgs = { inherit inputs; };
    modules = [
      # Inject the overlays
      ./overlays

      # Set some basic options
      {
        config = {
          nixpkgs.config = {
            allowUnfree = true;
            segger-jlink.acceptLicense = true;
          };
          networking.hostName = hostName;
          system.stateVersion = stateVersion;

          home-manager = {
            users.dzervas.home.stateVersion = stateVersion;
            extraSpecialArgs = { inherit desktop hostName isPrivate inputs; };

            # Allow home-manager to have access to nix-flatpak
            sharedModules = [
              inputs.flatpak.homeManagerModules.nix-flatpak
              inputs.nixvim.homeModules.nixvim
            ];
          };
        };
      }

      inputs.opnix.nixosModules.default

      inputs.stylix.nixosModules.stylix
      ./nixos
      ./hardware/${hostName}.nix
      ./desktop/${desktop}.nix

      inputs.home-manager.nixosModules.home-manager

      # Insert the secure boot module only here to avoid breaking the ISO
      (if (hostName != "iso") then inputs.lanzaboote.nixosModules.lanzaboote else {})

      (if isPrivate then
        builtins.trace "🔐 Private submodule build" ./home/.private
      else
        builtins.trace "📢 Public build" {})
    ];
  };

  # Create a map compatible with the `apps.<system>.<whatever>` variable that is just a shell script
  mkShellApp = pkgs: script: {
    type = "app";
    program = builtins.toString (pkgs.writeShellScript "script" script);
  };
}
