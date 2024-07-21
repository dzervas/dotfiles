{ lib, ... }:
let
  keys_str = builtins.fetchurl {
    url = "https://github.com/dzervas.keys";
    sha256 = "sha256:1wpgdqrvjqy9lldc6wns3i31sm1ic9yf7354q2c9j5hsfl2pbynh";
  };

  keys_lines = lib.strings.splitString "\n" keys_str;
in
{
  # (nixpkgs + "/nixos/modules/installer/cd-dvd/installation-cd-minimal.nix")
  # (nixpkgs + "/nixos/modules/installer/virtualbox-demo.nix")
  # (nixpkgs + "/nixos/modules/virtualisation/virtualbox-guest.nix")
  # Needs VboxSVGA video controller
  virtualisation.virtualbox.guest.enable = true;

  services.xserver.displayManager.lightdm.enable = false;
  services.xserver.desktopManager.plasma5.enable = lib.mkForce false;

  users.users.dzervas.extraGroups = [ "vboxsf" ];

  services.openssh = {
    enable = true;
    settings.PasswordAuthentication = true;
    settings.KbdInteractiveAuthentication = true;
  };

  users.users.dzervas.openssh.authorizedKeys.keys = keys_lines;

  boot.loader.grub.device = "/dev/sda";

  fileSystems = {
    "/" = {
      device = "/dev/sda1";
      fsType = "ext4";
    };
  };
}
