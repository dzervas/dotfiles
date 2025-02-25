{ pkgs, ... }: {
  hardware.graphics.enable = true;

  environment = {
    systemPackages = with pkgs; [
      gthumb
      libsecret
    ];
  };

  services = {
    logind = {
      lidSwitchDocked = "lock";
      lidSwitchExternalPower = "lock";
      extraConfig = ''
        IdleAction=lock
        IdleActionSec=5m
      '';
    };

  };

  services = {
    # FlatPak
    flatpak.enable = true;
    accounts-daemon.enable = true; # Flatpak needs this
  };

  security.polkit.enable = true;
}
