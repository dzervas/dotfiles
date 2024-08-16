{ config, lib, pkgs, ... }:
let
  swaylock = "${config.programs.swaylock.package}/bin/swaylock -f --grace 0";
  swaymsg = "${pkgs.sway}/bin/swaymsg";
  wpctl = "${pkgs.wireplumber}/bin/wpctl";
  configFile = "${config.xdg.configHome}/swayidle/config";
in
{
  services.swayidle = {
    enable = true;
    events = [
      { event = "before-sleep"; command = "playerctl pause"; }
      { event = "before-sleep"; command = swaylock; }
      { event = "lock"; command = swaylock; }
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
        command = "${swaymsg} output '*' dpms off";
        resumeCommand = "${swaymsg} output '*' dpms on";
      }
    ] else []);
  };

  home.file."${configFile}".text = let
    lines = map (e: ''${e.event} "${e.command}"'') config.services.swayidle.events ++
            map (t: if builtins.isNull t.resumeCommand then
                ''timeout ${toString t.timeout} "${t.command}"''
              else
                ''timeout ${toString t.timeout} "${t.command}" resume "${t.resumeCommand}"''
            ) config.services.swayidle.timeouts;
  in builtins.concatStringsSep "\n" lines;

  systemd.user.services.swayidle = lib.mkIf config.services.swayidle.enable {
    Install = {};
  };

  wayland.windowManager.sway.config.startup = [{ command = "${pkgs.swayidle}/bin/swayidle -w -C ${configFile}"; }];
}
