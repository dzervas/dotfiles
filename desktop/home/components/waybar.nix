{
  config,
  lib,
  pkgs,
  ...
}:
let
  inherit (lib) mkIf optionals;
  cfg = config.setup;

  niriSlots = builtins.genList (i: i + 1) 20;
  niriColumnModules = map (slot: "custom/niri-column-${toString slot}") niriSlots;

  niriColumnScript = pkgs.writeShellScript "waybar-niri-column" ''
    set -eu

    slot="$1"

    workspaces_json="$(${pkgs.niri}/bin/niri msg -j workspaces 2>/dev/null || true)"
    windows_json="$(${pkgs.niri}/bin/niri msg -j windows 2>/dev/null || true)"
    [ -n "$workspaces_json" ] || exit 0
    [ -n "$windows_json" ] || exit 0

    target="$(
      ${pkgs.jq}/bin/jq -cn --argjson slot "$slot" --argjson workspaces "$workspaces_json" --argjson windows "$windows_json" '
        ($workspaces | map({ key: (.id | tostring), value: .idx }) | from_entries) as $workspace_idx
        | ($windows
          | map(select(.is_floating | not))
          | map({
              id,
              workspace_id,
              column: .layout.pos_in_scrolling_layout[0],
              app_id,
              title,
              is_focused,
              focus_secs: .focus_timestamp.secs,
              focus_nanos: .focus_timestamp.nanos
            })
          | group_by([.workspace_id, .column])
          | map(sort_by(.focus_secs, .focus_nanos) | last)
          | sort_by(($workspace_idx[(.workspace_id | tostring)] // 9999), .column)
        )[$slot - 1] // empty
      '
    )"

    [ -n "$target" ] || exit 0

    app_id="$(printf '%s\n' "$target" | ${pkgs.jq}/bin/jq -r '.app_id // empty')"
    [ -n "$app_id" ] || exit 0

    title="$(printf '%s\n' "$target" | ${pkgs.jq}/bin/jq -r '.title // empty')"
    is_focused="$(printf '%s\n' "$target" | ${pkgs.jq}/bin/jq -r '.is_focused')"

    icon="󰣆 "
    case "$app_id" in
      brave*|chromium*|firefox*) icon=" " ;;
      com.mitchellh.ghostty|org.wezfurlong.wezterm|Alacritty|foot*|kitty) icon=" " ;;
      dev.zed.Zed*|code*|codium*|nvim*) icon="󰨞 " ;;
      com.slack.Slack|slack) icon=" " ;;
      discord*|vesktop) icon=" " ;;
      1password) icon="󰢁 " ;;
      org.telegram.desktop|telegramdesktop) icon=" " ;;
      spotify) icon=" " ;;
      steam*|steam_app_*) icon=" " ;;
    esac

    class=""
    if [ "$is_focused" = "true" ]; then
      class="active"
    fi

    ${pkgs.jq}/bin/jq -cn --arg text "$icon" --arg tooltip "$title" --arg class "$class" '{text: $text, tooltip: $tooltip, class: $class}'
  '';

  niriColumnFocusScript = pkgs.writeShellScript "waybar-niri-column-focus" ''
    set -eu

    slot="$1"

    workspaces_json="$(${pkgs.niri}/bin/niri msg -j workspaces 2>/dev/null || true)"
    windows_json="$(${pkgs.niri}/bin/niri msg -j windows 2>/dev/null || true)"
    [ -n "$workspaces_json" ] || exit 0
    [ -n "$windows_json" ] || exit 0

    window_id="$(
      ${pkgs.jq}/bin/jq -rnc --argjson slot "$slot" --argjson workspaces "$workspaces_json" --argjson windows "$windows_json" '
        ($workspaces | map({ key: (.id | tostring), value: .idx }) | from_entries) as $workspace_idx
        | ($windows
          | map(select(.is_floating | not))
          | map({
              id,
              workspace_id,
              column: .layout.pos_in_scrolling_layout[0],
              focus_secs: .focus_timestamp.secs,
              focus_nanos: .focus_timestamp.nanos
            })
          | group_by([.workspace_id, .column])
          | map(sort_by(.focus_secs, .focus_nanos) | last)
          | sort_by(($workspace_idx[(.workspace_id | tostring)] // 9999), .column)
        )[$slot - 1].id // empty
      '
    )"

    [ -n "$window_id" ] || exit 0
    ${pkgs.niri}/bin/niri msg action focus-window --id "$window_id"
  '';

  niriColumnSettings = builtins.listToAttrs (
    map (slot: {
      name = "custom/niri-column-${toString slot}";
      value = {
        return-type = "json";
        exec = "${niriColumnScript} ${toString slot}";
        interval = 1;
        hide-empty-text = true;
        on-click = "${niriColumnFocusScript} ${toString slot}";
      };
    }) niriSlots
  );
in
{
  setup.bar = "waybar";

  # Add some fonts for styling
  home.packages = with pkgs; [
    martian-mono
    nerd-fonts.jetbrains-mono
  ];

  stylix.targets.waybar = {
    font = "sansSerif";
    addCss = false;
  };

  programs.waybar = {
    enable = true;
    systemd.enable = true;

    style = lib.mkAfter (builtins.readFile ./waybar.style.css);
    settings = {
      mainBar = (
        {
          # Base
          layer = "top";
          mode = "dock";
          exclusive = true;

          # Appearance
          position = "top";
          spacing = 4;
          height = 30;

          # Module positioning
          modules-left = [
            "custom/power"
            "custom/launcher"
            # "custom/media"
          ]
          ++ optionals (cfg.windowManager == "hyprland") [ "hyprland/workspaces" ]
          ++ optionals (cfg.windowManager == "sway") [
            "sway/workspaces"
            "sway/scratchpad"
          ]
          ++ optionals (cfg.windowManager == "niri") niriColumnModules;
          modules-center = [
            (mkIf (cfg.windowManager == "sway") "sway/window")
            (mkIf (cfg.windowManager == "hyprland") "hyprland/window")
            (mkIf (cfg.windowManager == "niri") "niri/window")
          ];
          modules-right = [
            "mpris"
            "tray"
            # TODO: Replace with wireplumber
            # TODO: Bluetooth state when devices are connected
            # "pulseaudio"
            "keyboard-state"
            "battery"
            # "bluetooth"
            (mkIf (cfg.windowManager == "sway") "sway/language")
            (mkIf (cfg.windowManager == "hyprland") "hyprland/language")
            (mkIf (cfg.windowManager == "niri") "niri/language")
            "clock"
            "idle_inhibitor"
            "custom/notifications"
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
            format = " {icon}";
            format-icons = "󰐥";
            on-click-right = "loginctl lock-session";
          };
          "custom/launcher" = {
            format = " {icon}";
            format-icons = " ";
          };
          "custom/notifications" = lib.mkDefault {
            tooltip = false;
            format = "{icon}";
            format-icons = "";
          };
          "niri/window" = {
            icon = true;
            separate-outputs = true;
            rewrite = {
              "(.*) — Mozilla Firefox" = "$1";
            };
          };
          "niri/language" = {
            format = "{shortDescription}";
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
          "sway/window".icon = true;
          "sway/workspaces" = {
            format = "{icon} ";
            all-outputs = true;
            format-icons = {
              "1" = "";
              "2" = "";
              "3" = "󰨞";
              "4" = "";
              "5" = "";
            };
          };
          "hyprland/workspaces" = rec {
            format = "{icon} ";
            all-outputs = true;
            format-icons = {
              "1" = "";
              "2" = "";
              "3" = "󰨞";
              "4" = "";
              "5" = "";
            };
            # Generate an attrmap in the form of `<number> = []` so that all the iconed workspaces are persistent
            persistent-workspaces = lib.attrsets.mapAttrs (_: _: [ ]) format-icons;
          };
          "sway/scratchpad" = {
            format = "{icon}  {count}";
            format-icons = [
              ""
              ""
            ];
            show-empty = false;
            tooltip = true;
            tooltip-format = "{app}: {title}";
            on-click = "swaymsg scratchpad show";
          };

          mpris = {
            format = "{player_icon} {title}";
            format-paused = "<span color='grey'>{status_icon} {title}</span>";
            max-length = 30;
            player-icons = {
              default = "⏸";
              mpv = "🎵";
              firefox = " ";
            };
            status-icons = {
              paused = "▶";
              playing = "⏸";
            };
            tooltip-format-playing = "{title}\n\n{artist} - {album}\n{status} - {position}/{length}";
            tooltip-format-paused = "{title}\n\n{artist} - {album}\n{status} - {position}/{length}";
          };
          keyboard-state = {
            format = "{name}";
          };
          tray = {
            spacing = 10;
          };
          clock = {
            format = "{:%H:%M %a %d/%m}";
            tooltip-format = "<big>{:%Y %B}</big>\n<tt><small>{calendar}</small></tt>";
          };
          battery = {
            # TODO: Use states and have different format-icons per state
            states = {
              warning = 30;
              critical = 15;
            };
            format = "{icon} {capacity}%";
            format-charging = "⚡ {capacity}%";
            format-plugged = " {capacity}%";
            format-alt = "{time} {icon}";
            format-full = "󱟢";
            format-icons = [
              "󰁺"
              "󰁻"
              "󰁼"
              "󰁽"
              "󰁾"
              "󰁿"
              "󰂀"
              "󰂁"
              "󰂂"
              "󰁹"
            ];
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
              default = [
                ""
                ""
                ""
              ];
            };
            on-click = "pavucontrol";
          };
        }
        // niriColumnSettings
      );
    };
  };
}
