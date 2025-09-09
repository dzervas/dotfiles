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

  systemd.sleep.extraConfig = ''
    HibernateDelaySec=1h
    HibernateOnACPower=false
  '';

  security.polkit.enable = true;
}
