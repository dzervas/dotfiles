{ config, lib, pkgs, ... }: let
  inherit (lib) mkIf;
  cfg = config.setup;
in {
  setup.bar = "waybar";

  # Add some fonts for styling
  home.packages = with pkgs; [
    martian-mono
    nerd-fonts.jetbrains-mono
  ];

  programs.waybar = {
    enable = true;
    systemd.enable = true;

    style = lib.mkForce ./waybar.style.css;
    settings = {
      mainBar = rec {
        # Base
        layer = "top";
        mode = "dock";
        position = "top";
        spacing = 4;
        height = 30;
        exclusive = true;

        # Margins
        margin-top = 5;
        margin-bottom = 5;
        margin-left = 10;
        margin-right = margin-left;

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
          "mpris"
          "tray"
          # "pulseaudio"
          "keyboard-state"
          "battery"
          # "bluetooth"
          (mkIf (cfg.windowManager == "sway") "sway/language")
          (mkIf (cfg.windowManager == "hyprland") "hyprland/language")
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
        "hyprland/language" = {
          format = "{shortDescription}";
          on-click = "hyprctl switchxkblayout $(hyprctl devices -j | ${pkgs.jq}/bin/jq -r '.keyboards[] | select(.main) | .name') next";
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

        mpris = {
          format = "{player_icon} {dynamic}";
          format-paused = "<span color='grey'>{status_icon} {dynamic}</span>";
          max-length = 50;
          player-icons = {
            default = "⏸";
            mpv = "🎵";
          };
          status-icons = {
            paused = "▶";
          };
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
