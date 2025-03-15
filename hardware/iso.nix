{ config, inputs, lib, modulesPath, pkgs, ... }: let
  keys_str = builtins.fetchurl {
    url = "https://github.com/dzervas.keys";
    sha256 = "sha256:1wpgdqrvjqy9lldc6wns3i31sm1ic9yf7354q2c9j5hsfl2pbynh";
  };

  keys_lines = lib.strings.splitString "\n" keys_str;
in {
  # Use the minimal installation CD
  imports = [
    (modulesPath + "/installer/cd-dvd/installation-cd-minimal.nix")
    (modulesPath + "/installer/cd-dvd/channel.nix")
  ];

  isoImage = {
    isoName = lib.mkForce "dzervas-nixos-${config.system.nixos.label}.iso";
    # squashfsCompression = "gzip -Xcompression-level 1";
    squashfsCompression = "zstd -Xcompression-level 9";
    makeEfiBootable = true;
    makeUsbBootable = true;
    prependToMenuLabel = "DZervas ";
    # includeSystemBuildDependencies = true;
    contents = [{
      source = inputs.self.sourceInfo.outPath;
      target = "/flake_source";
    }];
  };

  users.users.dzervas.password = "nixos";
  networking.wireless.enable = lib.mkForce false;

  environment.systemPackages = with pkgs; [
    # For some reason it needs nix-shell -p xorg.xhost --run xhost si:localuser:root
    gparted
    tmux
  ];

  services.openssh = {
    enable = true;
    settings = {
      AllowUsers = [ "dzervas" ];
      KbdInteractiveAuthentication = false;
      PasswordAuthentication = false;
      PermitRootLogin = lib.mkForce "no";
    };
  };

  users.users.dzervas.openssh.authorizedKeys.keys = keys_lines;

  # Pin nixpkgs to the flake input, so that the packages installed
  # come from the flake inputs.nixpkgs.url.
  nix.registry.nixpkgs.flake = inputs.nixpkgs;
}
