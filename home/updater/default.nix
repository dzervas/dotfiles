{ config, pkgs, lib, ... }:

let
  # Configuration variables
  checkInterval = "1"; # minutes
  idleThreshold = 15; # minutes
  niceLevel = 19;
  stateDir = "$XDG_RUNTIME_DIR/flake-updater";
  dotfilesPath = "${config.home.homeDirectory}/Lab/dotfiles";

  # Script paths
  scriptsDir = ./.; # Points to home/updater/
  accumulateTime = "${scriptsDir}/accumulate-time.sh";
  buildFlake = "${scriptsDir}/build-flake.sh";
  monitorActivity = "${scriptsDir}/monitor-activity.sh";
in
{
  systemd.user = {
    services = {
      # Checks the system every interval to see if it's idle (or playing media).
      # If not, it raises the accumulator file by 1
      # Fired very often by its timer
      flake-accumulator = {
        Unit.Description = "Accumulate idle/media time for system updates";
        Service = {
          Type = "oneshot";
          Environment = [
            "STATE_DIR=${stateDir}"
            "IDLE_THRESHOLD=${toString idleThreshold}"
          ];
          ExecStart = "${pkgs.bash}/bin/bash ${accumulateTime}";
        };
      };

      # As soon as the accumulated number reaches the threshold (= the system has been idle for the configured time)
      # triggers the build
      # |
      # V

      # Builds (NOT switch or boot!) the pre-defined flake to generate cache
      # If the build succeeds, it rolls the flake.lock back and sends a desktop notification
      flake-builder = {
        Unit.Description = "Build NixOS system update in background";
        Service = {
          Type = "oneshot";
          Environment = [
            "DOTFILES_PATH=${dotfilesPath}"
          ];
          ExecStart = "${pkgs.bash}/bin/bash ${buildFlake}";
          # Start activity monitor when build starts
          ExecStartPost = "${pkgs.systemd}/bin/systemctl --user start flake-activity-monitor.timer";
        };
      };

      # Gets fired often by its timer as soon as the build starts.
      # Checks if the system activity is starting to ramp up and lowers the build process' nice to -19 (lowest).
      # As soon as the activity goes back down, it raises the nice back to 0
      flake-activity-monitor = {
        Unit.Description = "Monitor activity and adjust builder priority";
        Service = {
          Type = "oneshot";
          Environment = [
            "STATE_DIR=${stateDir}"
            "NICE_LEVEL=${toString niceLevel}"
          ];
          ExecStart = "${pkgs.bash}/bin/bash ${monitorActivity}";
        };
      };
    };

    timers = {
      flake-accumulator = {
        Unit.Description = "Timer for flake accumulator";
        Timer = {
          OnCalendar = "*:0/${checkInterval}";
          Persistent = true;
        };
        Install.WantedBy = [ "timers.target" ];
      };

      flake-activity-monitor = {
        Unit.Description = "Timer for activity monitoring during builds";
        Timer.OnCalendar = "*:0/${checkInterval}";
        # Note: This timer is started/stopped by flake-builder service
        # No Install section - not enabled by default
      };
    };
  };
}
