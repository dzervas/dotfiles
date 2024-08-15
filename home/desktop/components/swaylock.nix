{ config, lib, options, pkgs, ... }: let
  locker = "swaylock -f";
in {
  setup.locker = "${options.setup.locker.default}; ${locker}";
  programs.swaylock = {
    enable = true;
    package = pkgs.swaylock-effects;
    settings = {
      clock = true;
      grace = 5;
      fade-in = 0.1;
      effect-blur = "20x3";
      disable-caps-lock-text = true;
      show-keyboard-layout = true;
      show-failed-attempts = true;
    };
  };

  wayland.windowManager.sway = lib.mkIf config.wayland.windowManager.sway.enable {
    # Why does this not work in config.startup?
    extraConfig = "exec ${locker} --grace 0";
  };
}
