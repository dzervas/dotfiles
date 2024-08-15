{ config, lib, pkgs, ... }: let
  lock = "${pkgs._1password-gui}/bin/1password --lock --silent";
in {
  programs.ssh = {
    enable = true;
    extraConfig = ''
    Host *
        IdentityAgent ~/.1password/agent.sock
    '';
  };

  programs.git = {
    extraConfig = {
      gpg.format = "ssh";
      gpg."ssh".program = "${pkgs._1password-gui}/bin/op-ssh-sign";
    };
    signing.key = "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAINMUrtMAAGoiU1XOUnw2toDLMKCrhWXPuH8VY9X79IRj";
    signing.signByDefault = true;
  };

  services.swayidle = lib.mkIf config.services.swayidle.enable {
    events = [
      { event = "before-sleep"; command = lock;}
    ];
    timeouts = [
      { timeout = 300; command = lock;}
    ];
  };

  systemd.user.services._1password-tray = {
    Unit = {
      Description = "1password Tray";
      PartOf = [ "graphical-session.target" ];
      Requires = [ "tray.target" ];
      After = [
        "graphical-session-pre.target"
        "tray.target"
      ];
    };

    Service.ExecStart = "${pkgs._1password-gui}/bin/1password --silent";
    Install.WantedBy = [ "graphical-session.target" ];
  };
}
