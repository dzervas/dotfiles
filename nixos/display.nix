{ pkgs, ... }: {
  hardware.graphics = {
    enable = true;
    enable32Bit = true;
  };

  environment.systemPackages = with pkgs; [
    gthumb
    libsecret
  ];

  services = {
    logind = {
      lidSwitch = "suspend-then-hibernate";
      lidSwitchDocked = "suspend-then-hibernate";
      lidSwitchExternalPower = "suspend-then-hibernate";
      extraConfig = ''
        IdleAction=lock
        IdleActionSec=5m
        LidSwitchIgnoreInhibited=yes
        HibernateDelaySec=3600
      '';
    };

    # FlatPak
    flatpak.enable = true;
    accounts-daemon.enable = true; # Flatpak needs this
  };

  security.polkit.enable = true;
}
