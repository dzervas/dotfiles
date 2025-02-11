{ config, lib, pkgs, ... }: {
  setup.runner = "rofi -show combi";
  programs.rofi = {
    enable = true;
    location = "top";
    package = pkgs.rofi-wayland;
    plugins = with pkgs; [ (rofi-calc.override { rofi-unwrapped = rofi-wayland-unwrapped; }) ];

    extraConfig = rec {
      # Modes
      modes = "drun,filebrowser,power-menu,run,calc";
      combi-modes = modes;
      modi = "combi,calc";

      show-icons = true;
      auto-select = true;
      hover-select = true;
      click-to-exit = true;
    };

    yoffset =
      if config.programs.waybar.enable then
      # Move the rofi window below the bar (waybar)
        config.programs.waybar.settings.mainBar.height + 5
      else 0;
  };

  home.packages = with pkgs; [
    rofi-power-menu
  ];

  programs.waybar.settings.mainBar = lib.mkIf config.programs.waybar.enable {
    "custom/power".on-click = "rofi -no-fixed-num-lines -location 1 -theme-str 'window {width: 10%;}' -show menu -modi 'menu:rofi-power-menu --choices=suspend/shutdown/reboot'";
    "custom/launcher".on-click = "rofi -location 1 -theme-str 'window {width: 20%;}' -show drun";
  };
}
