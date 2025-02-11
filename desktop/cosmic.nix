{ inputs, ... }: {
  imports = [
    inputs.nixos-cosmic.nixosModules.default
  ];

  home-manager.sharedModules = [
    inputs.cosmic-manager.homeManagerModules.cosmic-manager
    ./home/cosmic.nix
  ];

  services = {
    desktopManager.cosmic.enable = true;
    displayManager.cosmic-greeter.enable = true;
  };
}
