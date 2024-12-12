{ config, pkgs, ... }: {
  home.packages = with pkgs; [
    rclone
    restic
    resticprofile
  ];

  systemd.user.services.restic = {
    Unit.Description = "Restic backup";
    Install.WantedBy = [ "default.target" ];
    Service = {
      # ExecStart = ["${pkgs.resticprofile}/bin/resticprofile documents.backup --config ${config.opnix.secrets.restic.path}"];
      ExecStart = ["${pkgs.resticprofile}/bin/resticprofile documents.backup"];
      Type = "oneshot";
    };
  };

  systemd.user.timers.restic = {
    Unit = {
      Description = "Restic backup timer";
      StartLimitBurst = 5;
      StartLimitIntervalSec = 300;
    };
    Install.WantedBy = [ "timers.target" ];
    Timer = {
      OnCalendar = "0/3:00";
      Persistent = true;
    };
  };
}
