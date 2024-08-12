{ config, pkgs, ... }:
let
  swaylock = "${config.programs.swaylock.package}/bin/swaylock -f --grace 0";
  swaymsg = "${pkgs.sway}/bin/swaymsg";
  wpctl = "${pkgs.wireplumber}/bin/wpctl";
in
{
  services.swayidle = {
    enable = true;
    systemdTarget = "sway-session.target";
    events = [
      { event = "before-sleep"; command = swaylock; }
    ];
    timeouts = [
      { timeout = 300; command = swaylock; }

      # Mute mic
      { timeout = 330; command = "${wpctl} set-mute @DEFAULT_SOURCE@ 1"; resumeCommand = "${wpctl} set-mute @DEFAULT_SOURCE@ 0"; }
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
        command = "${swaymsg} \"output * dpms off\"";
        resumeCommand = "${swaymsg} \"output * dpms on\"";
      }
    ] else []);
  };
}
