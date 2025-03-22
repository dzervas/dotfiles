{ config, lib, ... }: let
  inherit (lib) mkIf;
  cfg = config.setup;
in {
  setup.bar = "waybar";
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
          "custom/launcher"
          (mkIf (cfg.windowManager == "hyprland") "hyprland/workspaces")
          # "custom/media"
          (mkIf (cfg.windowManager == "sway") "sway/workspaces")
          (mkIf (cfg.windowManager == "sway") "sway/scratchpad")
        ];
        modules-center = [
          (mkIf (cfg.windowManager == "sway") "sway/window")
          (mkIf (cfg.windowManager == "hyprland") "hyprland/window")
        ];
        modules-right = [
          "tray"
          # "pulseaudio"
          "keyboard-state"
          "battery"
          # "bluetooth"
          (mkIf (cfg.windowManager == "sway") "sway/language")
          "clock"
          "idle_inhibitor"
        ];

        # Module settings
        "idle_inhibitor" = {
          format = "{icon}";
          format-icons = {
            activated = "🤪";
            deactivated = "😒";
          };
        };

        "bluetooth" = {
          format = "{icon}";
        };

        "custom/power" = {
          format = " {icon} ";
          format-icons = "󰐥";
          on-click-right = "loginctl lock-session";
        };
        "custom/launcher" = {
          format = " {icon} ";
          format-icons = "🚀";
        };
        "hyprland/window" = {
          icon = true;
          separate-outputs = true;
          rewrite = {
            "(.*) — Mozilla Firefox" = "$1";
          };
        };
        "sway/window" = {
          icon = true;
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
        "hyprland/workspaces" = {
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
        battery = {
          states = {
            warning = 30;
            critical = 15;
          };
          format = "{icon} {capacity}%";
          format-charging = "⚡ {capacity}%";
          format-plugged = "🔌 {capacity}%";
          format-alt = "{time} {icon}";
          format-full = "🔋 {capacity}%";
          format-icons = ["💀" "🪫" "🔋"];
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
