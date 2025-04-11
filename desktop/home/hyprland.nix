{ config, pkgs, ... }: let
  wpctl = "${pkgs.wireplumber}/bin/wpctl";
  mkRule = { rules, class ? null, title ? null }:
    map (rule:
      let
        classStr = if class != null then ",class:${class}" else "";
        titleStr = if title != null then ",title:${title}" else "";
      in "${rule}${classStr}${titleStr}") rules;
in {
  setup.windowManager = "hyprland";
  imports = [
    ./components/hypridle.nix
    ./components/hyprlock.nix
    ./components/rofi.nix
    ./components/trays.nix
    ./components/waybar.nix
    ./components/wayland-fixes.nix
  ];

  # home.pointerCursor.hyprcursor.enable = true;

  home.packages = with pkgs; [
    hyprshot
  ];

  services = {
    dunst.enable = true;
    hyprpolkitagent.enable = true;
  };

  wayland.windowManager.hyprland = {
    enable = true;
    settings = {
      general = {
        gaps_in = 2.5;
        gaps_out = 5;
      };

      exec-once = [
        "${pkgs.hyprland-per-window-layout}/bin/hyprland-per-window-layout"

        # Spawn inital windows
        "com.slack.Slack; hyprctl dispatch movetoworkspacesilent 4"
        "code; hyprctl dispatch movetoworkspacesilent 3"
        "firefox; hyprctl dispatch movetoworkspacesilent 2"
        "alacritty; hyprctl dispatch movetoworkspacesilent 1"

        # Arrange workspaces to screens
        "hyprctl dispatch moveworkspacetomonitor 1 0"
        "hyprctl dispatch moveworkspacetomonitor 2 1"
        "hyprctl dispatch moveworkspacetomonitor 3 1"
        "hyprctl dispatch moveworkspacetomonitor 4 0"
      ];

      "$mod" = "SUPER";
      bind = [
        "$mod, Return, exec, alacritty"
        "$mod, C, killactive"
        "$mod, E, exec, hyprctl keyword general:layout 'dwindle'"
        "$mod, E, exec, hyprctl keyword general:layout 'dwindle'"
        "$mod, T, exec, hyprctl keyword general:layout 'master'"
        "$mod, F, fullscreen"
        "$mod, G, togglegroup"
        "$mod, R, exec, ${config.setup.runner}"
        "$mod, P, exec, 1password --quick-access"
        "$mod, L, exec, ${config.setup.lockerInstant}"
        "$mod+Shift, F, togglefloating"
        "$mod+Shift, R, exec, hyprctl reload"
        "$mod, Left, workspace, m-1"
        "$mod+Shift, Left, movetoworkspacesilent, m-1"
        "$mod, Right, workspace, m+1"
        "$mod+Shift, Right, movetoworkspacesilent, m+1"
        "$mod, Up, cyclenext, tiled"
        "$mod, Up, changegroupactive"
        "$mod+Shift, Up, swapnext, tiled"
        "$mod+Shift, Up, movegroupwindow"
        "$mod, Down, cyclenext, tiled, prev"
        "$mod, Down, changegroupactive, back"
        "$mod+Shift, Down, swapnext, tiled, prev"
        "$mod+Shift, Down, movegroupwindow, back"

        "$mod, Tab, workspace, previous"
        "$mod, Comma, focusmonitor, +1"
        "$mod+Shift, Comma, movecurrentworkspacetomonitor, +1"
        "$mod, Period, focusmonitor, -1"
        "$mod+Shift, Period, movecurrentworkspacetomonitor, -1"
        ", Print, exec, hyprshot -z -m region --clipboard-only"
        "$mod, Print, exec, hyprshot -z -m output --clipboard-only"
      ] ++ (
        # workspaces
        # binds $mod + [shift +] {1..9} to [move to] workspace {1..9}
        builtins.concatLists (builtins.genList (i:
            let ws = i + 1;
            in [
              "$mod, code:1${toString i}, workspace, ${toString ws}"
              "$mod SHIFT, code:1${toString i}, movetoworkspace, ${toString ws}"
            ]
          )
          9)
      );

      bindl = [
        ", XF86AudioNext, exec, playerctl next"
        ", XF86AudioPause, exec, playerctl play-pause"
        ", XF86AudioPlay, exec, playerctl play-pause"
        ", XF86AudioPrev, exec, playerctl previous"
      ];
      bindel = [
        ",XF86AudioRaiseVolume, exec, wpctl set-volume @DEFAULT_AUDIO_SINK@ 5%+"
        ",XF86AudioLowerVolume, exec, wpctl set-volume @DEFAULT_AUDIO_SINK@ 5%-"
        ",XF86AudioMute, exec, wpctl set-mute @DEFAULT_AUDIO_SINK@ toggle"
        ",XF86AudioMicMute, exec, wpctl set-mute @DEFAULT_AUDIO_SOURCE@ toggle"
        ",XF86MonBrightnessUp, exec, brightnessctl s 10%+"
        ",XF86MonBrightnessDown, exec, brightnessctl s 10%-"
      ];

      # Mouse
      bindm = [
        "$mod, mouse:272, movewindow"
        "$mod, mouse:273, resizewindow"
      ];

      monitor = [
        # Monitor Name                                       , Mode  , Pos, Scale, <other params>
        "desc:GIGA-BYTE TECHNOLOGY CO. LTD. M27Q 24290B002448, highrr, 0x0, 1, vrr, 1"
        "desc:GIGA-BYTE TECHNOLOGY CO. LTD. M27Q 24290B002445, highrr, auto-right, 1, vrr, 1"
        "desc:BOE NE135A1M-NY1, highrr, auto, 1.67, vrr, 1"
        ", preferred, auto, 1" # Rule for additional monitors
      ];

      # Rules
      windowrule =
        # mkRule { title = "^1Password$"; class = "^1Password$"; rules = ["float" "center" "persistentsize" "pin" "stayfocused"]; } ++
        # mkRule { title = ".+— 1Password$"; rules = ["unset" "float" "center" "persistentsize"]; } ++
        mkRule { class = "jadx-gui-JadxGUI"; rules = ["float"]; } ++
        mkRule { class = "Steam Settings"; rules = ["float"]; } ++
        mkRule { class = "OrcaSlicer"; rules = ["suppressevent"]; };

      # Layouts
      master = {
        new_status = "master";
      };
      dwindle = {
        pseudotile = true;
        preserve_split = true;
      };

      workspace = [
        # No gaps or borders when only 1 window exists in the workspace
        # https://wiki.hyprland.org/Configuring/Workspace-Rules/#smart-gaps
        "w[tv1], gapsout:0, gapsin:0, border:false"
        "f[1], gapsout:0, gapsin:0, border:false"
      ];

      input = {
        kb_layout = "us,gr";
        kb_options = "grp:alt_space_toggle,caps:escape";
        repeat_rate = "56";
        repeat_delay = "200";
        touchpad = {
          natural_scroll = true;
          tap-to-click = true;
          clickfinger_behavior = true;
        };
      };

      debug = {
        disable_logs = false;
      };
    };

    # set the Hyprland and XDPH packages to null to use the ones from the NixOS module
    package = null;
    portalPackage = null;

    systemd = {
      # https://wiki.hyprland.org/Useful-Utilities/Systemd-start/#installation
      enable = false;
      enableXdgAutostart = true;
    };
  };
}
