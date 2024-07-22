{ config, lib, pkgs, ... }: {
  isoImage = {
    isoName = lib.mkForce "dzervas-${config.isoImage.isoBaseName}.iso";
    # squashfsCompression = "gzip -Xcompression-level 1";
    squashfsCompression = "zstd -Xcompression-level 9";
    makeEfiBootable = true;
    makeUsbBootable = true;
    prependToMenuLabel = "DZervas ";
    # includeSystemBuildDependencies = true;
  };

  users.users.dzervas.password = "nixos";
  networking.wireless.enable = lib.mkForce false;

  environment.systemPackages = with pkgs; [
    # For some reason it needs nix-shell -p xorg.xhost --run xhost si:localuser:root
    gparted
  ];
}
