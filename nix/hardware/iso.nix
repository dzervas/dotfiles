{ lib, pkgs, ... }: {
  isoImage.squashfsCompression = "gzip -Xcompression-level 1";

  users.users.dzervas.password = "nixos";
  networking.wireless.enable = lib.mkForce false;

  environment.systemPackages = with pkgs; [
    gparted
  ];
}
