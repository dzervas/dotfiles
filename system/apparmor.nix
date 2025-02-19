{ pkgs, ... }: {
  services.dbus.apparmor = "required";
  security.apparmor = {
    enable = true;
    killUnconfinedConfinables = true;
    packages = with pkgs; [
      apparmor-profiles
      roddhjav-apparmor-rules
    ];
  };
}
