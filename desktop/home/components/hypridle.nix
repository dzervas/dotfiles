{ config, pkgs, ... }: let
  wpctl = "${pkgs.wireplumber}/bin/wpctl";
in {
  services.hypridle = {
    enable = true;
    settings = {
      general = {
        lock_cmd = "${config.setup.passwordManagerLock} & ${config.setup.locker}";
        before_sleep_cmd = "${config.setup.passwordManagerLock} & ${config.setup.lockerInstant} ";
        after_sleep_cmd = "hyprctl dispatch dpms on";
      };
      listener = [
        { timeout = 300; on-timeout = config.setup.locker; }
        { timeout = 600; on-timeout = "hyprctl dispatch dpms off"; on-resume = "hyprctl dispatch dpms on"; }
        { timeout = 305; on-timeout = config.setup.passwordManagerLock; }
        { timeout = 330; on-timeout = "${wpctl} set-mute @DEFAULT_SOURCE@ 1"; on-resume = "${wpctl} set-mute @DEFAULT_SOURCE@ 0"; }
      ];
    };
  };
}
