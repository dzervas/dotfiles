# For more check https://blog.thomasheartman.com/posts/building-a-custom-nixos-installer
{ config, inputs, lib, modulesPath, pkgs, ... }: let
  keys_str = builtins.fetchurl {
    url = "https://github.com/dzervas.keys";
    sha256 = "sha256:0rncd8f8z1lhji65ddh6r4jx62nk499vcda5c06gbrfa1s9f7275";
  };

  keys_lines = lib.strings.splitString "\n" keys_str;
in {
  # Use the minimal installation CD
  imports = [
    (modulesPath + "/installer/cd-dvd/installation-cd-minimal.nix")
    (modulesPath + "/installer/cd-dvd/channel.nix")
  ];

  image.fileName = "dzervas-nixos-${config.system.nixos.label}.iso";

  isoImage = {
    squashfsCompression = "zstd -Xcompression-level 9";
    makeEfiBootable = true;
    makeUsbBootable = true;
    prependToMenuLabel = "DZervas ";
    # includeSystemBuildDependencies = true;
    contents = [{
      source = inputs.self.sourceInfo.outPath;
      target = "/dotfiles";
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

  fonts.fontconfig.enable = true; # kmscon requires it
  boot.zfs.forceImportRoot = false; # warning
}
