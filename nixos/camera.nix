{ lib, pkgs, ... }: let
  defaults = {
    # v4l2-ctl -L
    controls = {
      brightness = 128;
      contrast = 128;
      saturation = 128;

      white_balance_automatic = 1;
      backlight_compensation = 1;

      gain = 255;
      sharpness = 128;

      power_line_frequency = 1; # 1 = 50Hz, 2 = 60Hz, 0 = disabled

      auto_exposure = 1; # 1 = manual mode, 3 = aperture priority mode
      exposure_time_absolute = 2046;
      exposure_dynamic_framerate = 1;

      focus_automatic_continuous = 1;

      pan_absolute = 0;
      tilt_absolute = 0;
      # focus_absolute = 0; # Results in permission denied
      zoom_absolute = 100;
    };

    vidcap = {
      # v4l2-ctl --list-formats
      pixelformat = "YUYV";

      # v4l2-ctl --list-formats-ext
      resolution = "1920x1080";
    };

    fps = 30;

    # logitech_led1_mode = "auto";
    # logitech_led1_frequency = 24;
  };

  generateProfile = attrs: builtins.concatStringsSep " " (let
      resolution = lib.strings.splitString "x" attrs.vidcap.resolution;
      width = builtins.elemAt resolution 0;
      height = builtins.elemAt resolution 1;
    in [
      "--try-fmt-video=width=${width},height=${height},pixelformat=${attrs.vidcap.pixelformat}"
    ] ++
    (lib.attrsets.mapAttrsToList (k: v: "--set-ctrl=${k}=${toString v}") attrs.controls)
  );

  profiles = {
    default = {};
    high-light = {
      controls = {
        gain = 0;
        backlight_compensation = 0;

        auto_exposure = 3;
        exposure_time_absolute = 200;
        exposure_dynamic_framerate = 1;
      };
    };
    mid-light = {
      controls = {
        gain = 210;
        backlight_compensation = 0;

        auto_exposure = 3;
        exposure_time_absolute = null;
        exposure_dynamic_framerate = 1;
      };
    };
    low-light = {
      controls = {
        gain = 0;
        backlight_compensation = 0;

        auto_exposure = 3;
        exposure_time_absolute = null;
        exposure_dynamic_framerate = 1;
      };
    };
  };
in {
  # TODO: Trigger each profile with dbus + hour
  environment.systemPackages = [ pkgs.v4l-utils ];

  services.udev.extraRules = lib.mkAfter ''
    ACTION=="add", SUBSYSTEM=="usb", ENV{ID_VENDOR_ID}=="046d", RUN+="/bin/sh -c 'sleep 2; ${pkgs.v4l-utils}/bin/v4l2-ctl ${generateProfile (profiles.default // defaults)} --set-parm=${toString defaults.fps}'"
  '';


  environment.shellAliases = lib.attrsets.concatMapAttrs (name: profile: {
    "camera-profile-${name}" = "${pkgs.v4l-utils}/bin/v4l2-ctl ${generateProfile (profile // defaults)}";
  }) profiles;
}
