{ pkgs, ... }: {
  # Dependencies for the recording-sign script
  home.packages = with pkgs; [
    inotify-tools
    lsof
  ];

  systemd.user.services.recording-sign = {
    Unit = {
      Description = "Video camera watcher to toggle the camera accordingly";
      After = ["network-online.target"];
    };
    Service = {
      ExecStart = pkgs.writeShellScript "recording-sign.sh" ./recording-sign.sh;
      Restart = "on-failure";
      RestartSteps = 3;
      RestartMaxDelaySec = 6;
    };
    Install.WantedBy = [ "default.target" ];
  };
}
