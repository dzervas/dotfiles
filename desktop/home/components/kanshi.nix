{ config, lib, ... }: let
  cfg = config.setup;
in {
  services.kanshi = {
    enable = cfg.isLaptop;
    settings = [
      {
        profile.name = "undocked";
        profile.outputs = [{
          criteria = "eDP-1";
          status = "enable";
        }];
      }
      {
        profile.name = "docked";
        profile.outputs = [
          {
            criteria = "eDP-1";
            status = "disable";
          }
          {
            criteria = "Dell Inc. DELL P2419H C49BFZ2";
            status = "enable";
            position = "0,0";
            transform = "90";
          }
          {
            criteria = "Dell Inc. DELL S3422DWG B3F7KK3";
            status = "enable";
            position = "1080,492";
            scale = 1.25;
            mode = "3440x1440@60Hz";
          }
        ];
      }
    ];
  };

  wayland.windowManager.sway = lib.mkIf (config.wayland.windowManager.sway.enable && cfg.isLaptop) {
    config.startup = [{ command = "systemctl restart --user kanshi.service"; always = true; }];
  };
}
