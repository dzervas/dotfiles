{ config, lib, options, pkgs, ... }: let
  locker = "swaylock -f";
in {
  setup.locker = "${options.setup.locker.default}; ${locker}";
  setup.lockerInstant = config.setup.locker;
  programs.swaylock = {
    enable = true;

    settings = {
      ignore-empty-password = true;

      # Appearance
      indicator-idle-visible = true;
      indicator-radius = 100;

      # Keyboard stuff
      disable-caps-lock-text = true;
      show-keyboard-layout = true;
      show-failed-attempts = true;
    };
  };

  wayland.windowManager.sway = lib.mkIf config.wayland.windowManager.sway.enable {
    # Why does this not work in config.startup?
    extraConfig = "exec ${locker}";
  };
}
