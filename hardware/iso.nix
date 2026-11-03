# For more check https://blog.thomasheartman.com/posts/building-a-custom-nixos-installer
{
  config,
  inputs,
  lib,
  modulesPath,
  pkgs,
  ...
}: let
  keys = builtins.fetchurl {
    url = "https://github.com/dzervas.keys";
    sha256 = "sha256:1wpgdqrvjqy9lldc6wns3i31sm1ic9yf7354q2c9j5hsfl2pbynh";
  };
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
    contents = [
      { source = inputs.self.sourceInfo.outPath; target = "/dotfiles"; }
      { source = ./migrate-btrfs-raid.md; target = "/migrate-btrfs-raid.md"; }
    ];
  };

  users.users.dzervas.password = "nixos";
  networking.wireless.enable = true;

  environment.systemPackages = with pkgs; [
    # For some reason it needs nix-shell -p xorg.xhost --run xhost si:localuser:root
    gparted
    tmux

    # Tools for the migration guide included on the ISO.
    btrfs-progs
    coreutils
    cryptsetup
    diffutils
    dosfstools
    e2fsprogs
    gawk
    parted
    rsync
    systemd
    util-linux
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

  users.users.dzervas.openssh.authorizedKeys.keyFiles = [ keys ];

  # Pin nixpkgs to the flake input, so that the packages installed
  # come from the flake inputs.nixpkgs.url.
  nix.registry.nixpkgs.flake = inputs.nixpkgs;

  fonts.fontconfig.enable = true; # kmscon requires it
  boot.zfs.forceImportRoot = false; # warning
}
