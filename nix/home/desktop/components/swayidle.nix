{ config, lib, pkgs, ... }:
let
  swaylock = "${pkgs.swaylock}/bin/swaylock -f";
  swaymsg = "${pkgs.sway}/bin/swaymsg";
  wpctl = "${pkgs.wireplumber}/bin/wpctl";
in
{
  services.swayidle = {
    enable = true;
    events = [
      { event = "before-sleep"; command = swaylock; }
    ];
    timeouts = [
      { timeout = 300; command = swaylock; }
      # Mute mic
      { timeout = 330; command = "${wpctl} set-mute @DEFAULT_SOURCE@ 1"; resumeCommand = "${wpctl} set-mute @DEFAULT_SOURCE@ 0"; }
      # Turn off displays (sway)
      (lib.optionals config.wayland.windowManager.sway.enable ({
        timeout = 600;
        command = "${swaymsg} 'output * dpms off'";
        resumeCommand = "${swaymsg} 'output * dpms on'";
      }))
    ];
  };
}
