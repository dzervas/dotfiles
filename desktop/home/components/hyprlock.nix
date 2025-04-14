{ lib, options, ... }: let
  locker = "hyprlock --immediate --immediate-render --no-fade-in";
in {
  # TODO: Show weather, battery status, media
  # Weather from https://www.yr.no/en/forecast/daily-table/2-257282/Greece/Thessaly/L%C3%A1risa/Melivoia

  setup.locker = "${options.setup.locker.default}; hyprlock --immediate --immediate-render --no-fade-in";
  setup.lockerInstant = "${options.setup.locker.default}; hyprlock";

  programs.hyprlock = {
    enable = true;
    settings = {
      general = {
        grace = 5;
        hide_cursor = true;
        ignore_empty_input = true;
        fail_timeout = 1000;
      };

      background = lib.mkForce [{
        path = "screenshot";
        blur_size = 6;
        blur_passes = 2;
        noise = 0.0117;
        contrast = 1.3000;
        brightness = 0.8000;
        vibrancy = 0.2100;
        vibrancy_darkness = 0.0;
      }];

      label = [
      {
        text = "cmd[update:1000] date +'%H:%m'";

        font_size = 80;
        font_family = "Iosevka Term Extrabold";

        position = "0, -200";
        halign = "center";
        valign = "top";
      }
      {
        text = "cmd[update:1000] if [ $ATTEMPTS -gt 0 ]; then echo 🕵️‍♂️ $ATTEMPTS; fi";

        font_size = 40;
        font_family = "Iosevka Term Extrabold";

        position = "0, 100";
        halign = "center";
        valign = "bottom";
      }
      ];
    };
  };
}
