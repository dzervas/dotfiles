{ ... }: {
  programs.waybar = {
    enable = true;

    settings = {
      mainBar = {
        # Base
        layer = "bottom";
        position = "top";
        spacing = 4;
        height = 30;

        # Module positioning
        modules-left = [
          "custom/power"
          "sway/workspaces"
          "sway/scratchpad"
          # "custom/media"
        ];
        # modules-center = [ "sway/window" ];
        modules-center = [ "wlr/taskbar" ];
        modules-right = [
          "tray"
          # "pulseaudio"
          "keyboard-state"
          "sway/language"
          "clock"
        ];

        # Module settings
        "custom/power" = {
          format = " {icon} ";
          format-icons = "󰐥";
        };
        "wlr/taskbar" = {
          active-first = true;
          format = "{icon} {title}";
          on-click = "activate";
          on-click-middle = "close";
        };
        "sway/workspaces" = {
          format = "{icon} ";
          # TODO: Show the name with format-activated
          format-icons = {
            "1" = "";
            "2" = "";
            "3" = "";
            "4" = "";
            "5" = "";
          };
        };
        "sway/scratchpad" = {
          format = "{icon}  {count}";
          format-icons = [ "" "" ];
          show-empty = false;
          tooltip = true;
          tooltip-format = "{app}: {title}";
          on-click = "swaymsg scratchpad show";
        };
        keyboard-state = {
          format = "{name}";
        };
        tray = {
          spacing = 10;
        };
        clock = {
          format = "{:%H:%M %d/%m}";
          tooltip-format = "<big>{:%Y %B}</big>\n<tt><small>{calendar}</small></tt>";
        };
        pulseaudio = {
          format = "{volume}% {icon} {format_source}";
          format-bluetooth = "{volume}% {icon} {format_source}";
          format-bluetooth-muted = " {icon} {format_source}";
          format-muted = " {format_source}";
          format-source = "{volume}% ";
          format-source-muted = "";
          format-icons = {
            headphone = "";
            hands-free = "";
            headset = "";
            phone = "";
            portable = "";
            car = "";
            default = [ "" "" "" ];
          };
          on-click = "pavucontrol";
        };
      };
    };
  };
}
