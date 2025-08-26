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
    logind.settings.Login = {
      IdleAction = "lock";
      IdleActionSec = "5m";

      HibernateDelaySec = 3600;
      KillUserProcesses = true;

      LidSwitchIgnoreInhibited = true;
      HandleLidSwitch = "suspend-then-hibernate";
      HandleLidSwitchDocked = "suspend-then-hibernate";
      HandleLidSwitchExternalPower = "suspend-then-hibernate";
    };

    # FlatPak
    flatpak.enable = true;
    accounts-daemon.enable = true; # Flatpak needs this
  };

  security.polkit.enable = true;
}
