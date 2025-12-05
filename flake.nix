{
  description = "NixOS configuration flake";

  outputs = { nixpkgs, flake-utils, nixvim, nix-private, ... }@inputs: let
    inherit (nixpkgs) lib;
    inherit (flake-utils.lib) eachDefaultSystemPassThrough mkApp;

    # "Private build" mode. If enabled the private nix files will be used.
    # Disabled to be able to build the ISO and initial installation
    inherit (nix-private) isPrivate;
    desktop = "hyprland";

    inherit (import ./mkMachine.nix { inherit inputs lib desktop; }) mkMachine mkShellApp;
  in rec {
    # System definition
    # If you're here to check how to make your own flake for nixos, only the following matters
    # in the outputs. The rest are "nice to haves".
    nixosConfigurations = {
      desktop = mkMachine { inherit isPrivate; hostName = "desktop"; stateVersion = "24.11"; };
      laptop = mkMachine { inherit isPrivate; hostName = "laptop"; stateVersion = "25.05"; };
      iso = mkMachine { isPrivate = false; hostName = "iso"; stateVersion = "25.05"; };
    };

    # Helper to be able to do `nix build .#iso`
    iso = nixosConfigurations.iso.config.system.build.isoImage;

    # Some additional apps to run directly with `nix run github:dzervas/dotfiles#<app>`
    # If you're browsing flake configs, you should probably skip the whole `apps` variable,
    # it's ugly but I couldn't find a better way to configure these one-off cases.
    # The end result though is neat! `nix run .#<app>` and you're ready to go!
    apps = eachDefaultSystemPassThrough (system: {
      ${system} = let
        pkgs = nixpkgs.legacyPackages.${system};
      in rec {
        # Nixvim is a bit esoteric as to how to generate a package and then use it as an app
        # It has a built-in function that accepts the config and spits out a package
        # that we then pass to mkApp - but with the correct binary name
        nvim = let
          # Import the config file - just like home-manager expects it
          nixvimConfigFile = import ./home/neovim { inherit pkgs; };
          # Pull out only the nixvim config (not home.* or whatever)
          nixvimConfigFull = nixvimConfigFile.programs.nixvim;
          # The "standalone" mode nixvim doesn't have some keys so we filter them out
          nixvimConfig = builtins.removeAttrs nixvimConfigFull [
            "enable"
            "defaultEditor"
            "viAlias"
            "vimAlias"
            "vimdiffAlias"
          ];
          # Use the `makeNixvim` function with the extracted config to make a custom package
          drv = nixvim.legacyPackages.${system}.makeNixvim nixvimConfig;
        in mkApp { inherit drv; exePath = "/bin/nvim"; };

        # TODO: Get rid of the update-shim
        update = mkShellApp pkgs (builtins.readFile ./.github/scripts/flake-update.sh);

        # script to authenticate
        iso-auth = mkShellApp pkgs ''
          echo "Authenticating to github from oras"
          set -x
          ${pkgs.gh}/bin/gh auth token | ${pkgs.oras}/bin/oras login ghcr.io --password-stdin -u github
        '';

        # script to download the iso
        iso-get = mkShellApp pkgs ''
          echo "Downloading iso from github - assuming you've authenticated with the iso-auth script"
          set -x
          ${pkgs.oras}/bin/oras pull ghcr.io/dzervas/dotfiles/nixos-iso:latest
        '';

        default = nvim;
      };

      # TODO: Expose the overlays as packages
      # packages = eachDefaultSystemPassThrough (system: {
      #   ${system} = let
      #     pkgs = nixpkgs.legacyPackages.${system};
      #     overlay = import ./overlays;
      #     overlayPackages = overlay pkgs pkgs;
      #   in overlayPackages;
      # });
    });
  };

  inputs = {
    nixpkgs.url = "github:nixos/nixpkgs/nixos-unstable";
    flake-utils.url = "github:numtide/flake-utils";
    home-manager.url = "github:nix-community/home-manager";
    home-manager.inputs.nixpkgs.follows = "nixpkgs";

    # ISO generation & laptop stuff
    nixos-hardware.url = "github:NixOS/nixos-hardware/master";

    # 1Password secrets
    opnix.url = "github:dzervas/opnix";
    opnix.inputs.nixpkgs.follows = "nixpkgs";

    # Secure boot
    lanzaboote.url = "github:nix-community/lanzaboote";
    lanzaboote.inputs = {
      nixpkgs.follows = "nixpkgs";
      rust-overlay.follows = "rust-overlay";
    };

    # Home stuff
    stylix.url = "github:danth/stylix";
    flatpak.url = "github:gmodena/nix-flatpak";
    nixvim.url = "github:nix-community/nixvim";
    nixvim.inputs.nixpkgs.follows = "nixpkgs";

    nix-private.url = "path:.github/dummy";
    nix-private.inputs.nixpkgs.follows = "nixpkgs";

    # HyprLand
    hyprland.url = "github:hyprwm/Hyprland";
    # hyprland-dynamic-cursors.url = "github:VirtCode/hypr-dynamic-cursors";
    # hyprland-dynamic-cursors.inputs.hyprland.follows = "hyprland";
    hyprland-hy3.url = "github:outfoxxed/hy3";
    hyprland-hy3.inputs.hyprland.follows = "hyprland";

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

    # Lanzaboote fix:
    # https://github.com/nix-community/lanzaboote/pull/485
    rust-overlay = {
      url = "github:oxalica/rust-overlay";
      inputs.nixpkgs.follows = "nixpkgs";
    };
  };

  nixConfig.ssh-auth-sock = "env:SSH_AUTH_SOCK";
}
