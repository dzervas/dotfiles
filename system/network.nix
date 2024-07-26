{ config, lib, pkgs, ... }: {
  networking.networkmanager.enable = true;
  # networking.wireless.enable = false; # Can't use with networkmanager???

  # Firewall
  networking.firewall.enable = true;
  networking.firewall.allowedTCPPorts = [ 8181 ];

  time.timeZone = "Europe/Athens";

  boot.extraModulePackages = with config.boot.kernelPackages; [
    rtl88xxau-aircrack
  ];

  # services.zerotierone = lib.mkIf config.isPrivate {
  #   enable = true;
  #   joinNetworks = [
  #     builtins.exec "${pkgs._1password}/bin/op read op://local/zerotier/network_id"
  #   ];
  # };
}
