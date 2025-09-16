{ config, lib, pkgs, ... }: {
  setup.runner = "rofi -show combi";
  programs.rofi = let
    # Used to denote that a value should not be quoted within CSS
    inherit (config.lib.formats.rasi) mkLiteral;
    inherit (lib) mkForce;
  in {
    enable = true;

    location = "center";
    plugins = with pkgs; [ rofi-calc ];

    theme = lib.mkAfter {
      "*" = {
        background-color = mkForce (mkLiteral "transparent");
        margin = mkLiteral "0px";
        padding = mkLiteral "0px";
        spacing = mkLiteral "0px";
      };

      window.border-radius = mkLiteral "24px";
      mainbox.padding = mkLiteral "12px";

      inputbar = {
        background-color = mkLiteral "@normal-background";
        border-color = mkLiteral "@selected-active-background";

        border = mkLiteral "2px";
        border-radius = mkLiteral "16px";

        padding = mkLiteral "8px 16px";
        spacing = mkLiteral "8px";
        children = map mkLiteral ["prompt" "entry"];
      };

      entry = {
        placeholder = "Search";
        placeholder-color = mkLiteral "@separatorcolor";
      };

      message = {
        margin = mkLiteral "12px 0 0";
        border-radius = mkLiteral "16px";
        background-color = mkLiteral "@separatorcolor";
      };

      textbox.padding = mkLiteral "8px 24px";

      listview = mkForce {
        background-color = mkLiteral "transparent";

        margin = mkLiteral "12px 0 0";
        lines = mkLiteral "8";
        columns = mkLiteral "1";

        fixed-height = false;
      };

      element = {
        padding = mkLiteral "8px 16px";
        spacing = mkLiteral "8px";
        border-radius = mkLiteral "16px";
      };

      element-icon = {
        size = mkLiteral "1em";
        vertical-align = mkLiteral "0.5";
      };
    };

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

  programs.waybar.settings.mainBar = let
    suspend = if config.setup.isLaptop then "hibernate/" else "suspend/";
  in {
    "custom/power".on-click = "rofi -no-fixed-num-lines -location 1 -theme-str 'window {width: 10%;}' -show menu -modi 'menu:rofi-power-menu --choices=${suspend}shutdown/reboot/logout'";
    "custom/launcher".on-click = "rofi -location 1 -theme-str 'window {width: 20%;}' -show drun";
  };
}
