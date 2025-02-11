{ pkgs, ... }: {
  hardware.graphics.enable = true;

  environment = {
    # Electron fix - https://nixos.wiki/wiki/Wayland#Electron_and_Chromium
    sessionVariables.NIXOS_OZONE_WL = "1";
    # sessionVariables.COSMIC_DATA_CONTROL_ENABLED = 1;

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
