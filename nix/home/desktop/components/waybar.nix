{ pkgs, ... }: {
  programs.waybar = {
    enable = true;

    settings = {
      mainBar = {
        # Base
        layer = "top";
        position = "top";
        spacing = 4;

        # Module positioning
        modules-left = [
          "sway/workspaces"
          "sway/scratchpad"
          # "custom/media"
        ];
        modules-center = [ "sway/window" ];
        modules-right = [
          "tray"
          # "pulseaudio"
          "keyboard-state"
          "sway/language"
          "clock"
        ];

        # Module settings
        "sway/workspaces" = {
          format = "{icon}";
          # TODO: Show the name with format-activated
          format-icons = {
            "1" = "";
            "2" = "";
            "3" = "";
            "4" = "";
            "5" = "";
          };
        };
        "keyboard-state" = {
          format = "{name}";
        };
        "sway/scratchpad" = {
          format = "{icon} {count}";
          format-icons = [ "" "" ];
          show-empty = false;
          tooltip = true;
          tooltip-format = "{app}: {title}";
        };
        "tray" = {
          spacing = 10;
        };
        "clock" = {
          format = "{:%H:%M %d/%m}";
          tooltip-format = "<big>{:%Y %B}</big>\n<tt><small>{calendar}</small></tt>";
        };
        "pulseaudio" = {
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
              default = ["" "" ""];
          };
          on-click = "pavucontrol";
        };
      };
    };
  };
}
