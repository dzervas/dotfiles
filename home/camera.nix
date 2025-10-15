{ lib, pkgs, ... }: let
  defaults = {
    brightness = 128;
    contrast = 128;
    saturation = 128;

    white_balance_automatic = 1;
    gain = 255;
    sharpness = 128;

    power_line_frequency = "60_hz";
    backlight_compensation = 1;

    auto_exposure = "manual_mode";
    exposure_time_absolute = 2047;
    exposure_dynamic_framerate = 1;

    pan_absolute = 0;
    tilt_absolute = 0;

    focus_automatic_continuous = 1;
    zoom_absolute = 100;

    pixelformat = "MJPG";
    resolution = "1280x720";
    fps = 60;

    logitech_led1_mode = "auto";
    logitech_led1_frequency = 24;
  };
  iniGenerator = lib.generators.toINI {
    mkKeyValue = lib.generators.mkKeyValueDefault {} "=";
  };
in {
  # TODO: Trigger each profile with dbus + hour
  home.packages = [ pkgs.cameractrls-gtk4 ];
  home.file.".config/hu.irl.cameractrls/usb-046d_C922_Pro_Stream_Webcam_F0C8256F-video-index0.ini".text = iniGenerator {
    preset_1 = defaults;
    preset_2 = defaults // {
      gain = 210;
      backlight_compensation = 0;

      auto_exposure = "aperture_priority_mode";
      exposure_time_absolute = 1423;
      exposure_dynamic_framerate = 1;
    };
    preset_3 = defaults // {
      gain = 0;
      backlight_compensation = 0;

      auto_exposure = "aperture_priority_mode";
      exposure_time_absolute = 1423;
      exposure_dynamic_framerate = 1;
    };
  };
}
