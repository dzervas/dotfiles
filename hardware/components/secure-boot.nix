{ lib, ... }: {
  boot.loader.systemd-boot.enable = lib.mkForce false;
  boot.lanzaboote = {
    enable = true;
    configurationLimit = 3;
    pkiBundle = "/var/lib/sbctl";
    # Make simpledrm (and so plymouth) inherit the highest GOP resolution
    settings.console-mode = "max";
  };
}
