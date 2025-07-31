{ pkgs, ... }: {
  # TODO: Mark all partitions as noexec apart from /nix/store/

  users.users.dzervas = {
    isNormalUser = true;
    extraGroups = [ "wheel" "audio" "video" "uucp" "uinput" "vboxusers" "gamemode" "dialout" "libvirtd" "podman" "lp" ];
    shell = pkgs.fish;
  };

  home-manager = {
    useGlobalPkgs = true;
    useUserPackages = true;
    users.dzervas = import ../home;
  };

  # Allow rootless dmesg
  boot.kernel.sysctl."kernel.dmesg_restrict" = false;

  # Fix flatpak default browser
  systemd.user.extraConfig = "DefaultEnvironment=\"PATH=/run/current-system/sw/bin\"";

  # Fix home-manager xdg desktop portal support
  environment.pathsToLink = [ "/share/xdg-desktop-portal" "/share/applications" ];

  # Serial comms rules (for Arduino n stuff)
  # services.udev.packages = with pkgs; [ platformio-core.udev ];

  security = {
    audit.enable = true;
    auditd.enable = true;
    pam.services = {
      root.ttyAudit.enable = true;
      dzervas.ttyAudit.enable = true;
    };
    sudo.execWheelOnly = true;
  };

}
