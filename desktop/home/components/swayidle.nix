{ config, lib, pkgs, ... }:
let
  swaylock = "${config.programs.swaylock.package}/bin/swaylock -f; ${config.setup.passwordManagerLock}";
  swaymsg = "${pkgs.sway}/bin/swaymsg";
  niri = "${pkgs.niri}/bin/niri";
  # wpctl = "${pkgs.wireplumber}/bin/wpctl";
  configFile = "${config.xdg.configHome}/swayidle/config";
in
{
  services.swayidle = {
    enable = true;
    events = {
      before-sleep = "playerctl pause; ${config.setup.passwordManagerLock}";
      lock = swaylock;
      # { event = "before-sleep"; command = swaylock; }
      # Before-sleep lock is not triggered for some reason
      after-resume = swaylock;
    };
    timeouts = [
      { timeout = 300; command = swaylock; }

      # Mute mic
      # { timeout = 330; command = "${wpctl} set-mute @DEFAULT_SOURCE@ 1"; resumeCommand = "${wpctl} set-mute @DEFAULT_SOURCE@ 0"; }
    ] ++ (if config.wayland.windowManager.sway.enable then [
      # Sway
      {
        # Switch to english layout
        timeout = 330;
        command = "${swaymsg} input '*' xkb_switch_layout 0";
      }
      {
        # Turn off displays
        timeout = 600;
        command = "${swaymsg} output '*' dpms off";
        resumeCommand = "${swaymsg} output '*' dpms on";
      }
    ] else if config.setup.windowManager == "niri" then [
      {
        # Switch to english layout
        timeout = 330;
        command = "${niri} msg action switch-layout 0";
      }
      {
        # Turn off displays
        timeout = 600;
        command = "${niri} msg action power-off-monitors";
        resumeCommand = "${niri} msg action power-on-monitors";
      }
    ] else []);
  };

  # Execute swayidle manually if we're using sway
  systemd.user.services.swayidle = lib.mkIf config.services.swayidle.enable { Install = {}; };
  wayland.windowManager.sway.config.startup = [{ command = "${pkgs.swayidle}/bin/swayidle -w -C ${configFile}"; }];
}
