{ config, lib, pkgs, ... }: let
  script = pkgs.writeShellScript "recording-sign.sh" ./recording-sign.sh;
in {
  # Dependencies for the recording-sign script
  home.packages = with pkgs; [
    inotify-tools
    lsof
  ];

  systemd.user.services.recording-sign = {
    Unit = {
      Description = "Video camera watcher to toggle the camera accordingly";
      After = ["network-online.target"];
      X-Restart-Triggers = [ script ];
    };
    Service = {
      ExecStart = script;
      Restart = "on-failure";
      RestartSteps = 3;
      RestartMaxDelaySec = 6;
    };
    Install.WantedBy = lib.mkIf (!config.setup.isLaptop) [ "default.target" ];
  };
}
