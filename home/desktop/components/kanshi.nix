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
            criteria = "Dell Inc. DELL P2419H 6P7BFZ2";
            status = "enable";
            position = "0,0";
          }
          {
            criteria = "Dell Inc. DELL P2419H C49BFZ2";
            status = "enable";
            position = "1920,0";
          }
        ];
      }
    ];
  };

  wayland.windowManager.sway = lib.mkIf (config.wayland.windowManager.sway.enable && cfg.isLaptop) {
    config.startup = [{ command = "systemctl restart --user kanshi.service"; always = true; }];
  };
}
