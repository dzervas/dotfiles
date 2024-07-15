{ lib, pkgs, ... }: {
  # imports = [<nixpkgs/nixos/modules/installer/cd-dvd/installation-cd-minimal.nix>];

  users.users.dzervas.password = "nixos";
  networking.wireless.enable = lib.mkForce false;

  environment.systemPackages = with pkgs; [
    gparted
  ];
}
