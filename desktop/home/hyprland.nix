{ config, lib, pkgs, ... }: let
  mkRule = { rules, class ? null, title ? null }:
    map (rule:
      let
        classStr = if class != null then ",class:${class}" else "";
        titleStr = if title != null then ",title:${title}" else "";
      in "${rule}${classStr}${titleStr}") rules;
  mkRules = rules: builtins.concatLists (map mkRule rules);
in {
  setup.windowManager = "hyprland";
  imports = [
    ./components/hypridle.nix
    ./components/hyprlock.nix
    ./components/rofi.nix
    ./components/swaync.nix
    ./components/trays.nix
    ./components/waybar.nix
    ./components/wayland-fixes.nix
  ];

  home.packages = with pkgs; [
    hyprshot
    xfce.thunar # Needs to exist here too to be the default
  ];

  gtk.enable = true;
  qt.enable = true;

  services.hyprpolkitagent.enable = true;

  wayland.windowManager.hyprland = {
    enable = true;
    settings = {
      general = {
        gaps_in = 2;
        gaps_out = 5;
      };

      exec-once = [
        "${pkgs.hyprland-per-window-layout}/bin/hyprland-per-window-layout"

        # Spawn inital windows
        # TODO: Fix this
        # "com.slack.Slack; hyprctl dispatch movetoworkspacesilent 4"
        # "code; hyprctl dispatch movetoworkspacesilent 3"
        # "firefox; hyprctl dispatch movetoworkspacesilent 2"
        # "alacritty; hyprctl dispatch movetoworkspacesilent 1"

        # Arrange workspaces to screens
        # "hyprctl dispatch moveworkspacetomonitor 1 0"
        # "hyprctl dispatch moveworkspacetomonitor 2 1"
        # "hyprctl dispatch moveworkspacetomonitor 3 1"
        # "hyprctl dispatch moveworkspacetomonitor 4 0"
      ];

      "$mod" = "SUPER";
      bind = [
        # To check if the active window is grouped: hyprctl clients -j | jq --exit-status '.[] | select(.focusHistoryID == 0 and (.grouped | length) > 0)'
        "$mod, Return, exec, ${config.setup.terminal}"
        "$mod, C, killactive"
        "$mod+Shift, C, forcekillactive"
        "$mod, E, exec, hyprctl keyword general:layout 'dwindle'"
        "$mod, E, exec, hyprctl keyword general:layout 'dwindle'"
        "$mod, T, exec, hyprctl keyword general:layout 'master'"
        "$mod, F, fullscreen"
        "$mod, G, togglegroup"
        "$mod+Shift, G, moveoutofgroup"
        "$mod, R, exec, ${config.setup.runner}"
        "$mod, P, exec, 1password --quick-access"
        "$mod, L, exec, ${config.setup.lockerInstant}"
        "$mod+Shift, F, togglefloating"
        "$mod+Shift, R, exec, hyprctl reload"
        "$mod, Left, workspace, m-1"
        "$mod+Shift, Left, movetoworkspacesilent, m-1"
        "$mod, Right, workspace, m+1"
        "$mod+Shift, Right, movetoworkspacesilent, m+1"

        # Window selection
        "$mod, Up, cyclenext, tiled"
        "$mod+Alt, Up, changegroupactive"
        "$mod+Shift, Up, swapnext, tiled"
        "$mod+Alt+Shift, Up, movegroupwindow"
        "$mod, Down, cyclenext, tiled, prev"
        "$mod+Alt, Down, changegroupactive, b"
        "$mod+Shift, Down, swapnext, tiled, prev"
        "$mod+Alt+Shift, Down, movegroupwindow, b"

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
        "desc:GIGA-BYTE TECHNOLOGY CO. LTD. M27Q 24290B002445, highrr, 0x0,              1,    vrr, 1"
        "desc:GIGA-BYTE TECHNOLOGY CO. LTD. M27Q 24290B002448, highrr, auto-right,       1,    vrr, 1"
        "desc:BOE NE135A1M-NY1,                                highrr, 0x0,              1.67, vrr, 1" # Built-in monitor
        # "DP-3,                                                 highrr, auto-center-up,   1,    vrr, 1"
        ", preferred, auto, 1" # Rule for additional monitors
      ];

      # Rules
      # TODO: Move the rules to each program
      # TODO: Define a global mkWindowRule function that each wm overrides
      windowrule = mkRules [
        # mkRule { title = "^1Password$"; class = "^1Password$"; rules = ["float" "center" "persistentsize" "pin" "stayfocused"]; }
        # mkRule { title = ".+— 1Password$"; rules = ["unset" "float" "center" "persistentsize"]; }
        { title = "1Password"; class = "1Password"; rules = ["float" "center" ]; }
        { class = "jadx-gui-JadxGUI"; rules = ["float"]; }
        { class = "firefox"; title = "Picture-in-Picture"; rules = ["float" "center"]; }
        { class = "Steam Settings"; rules = ["float"]; }
        { class = "OrcaSlicer"; rules = ["suppressevent"]; }
        { class = "org.pulseaudio.pavucontrol"; rules = ["float" "center"]; }
        { title = "Ropuka's Idle Island"; rules = ["float" "persistentsize" "fullscreenstate 0 0"]; }
        { title = "atuin-desktop"; rules = ["float"]; }
        { class = "spotify"; rules = ["float" "center"]; }
        { class = "thunar"; title = ''^Rename ".*"$''; rules = ["float"]; }
      ];

      # Layouts
      master = {
        new_status = "master";
      };
      dwindle = {
        pseudotile = true;
        preserve_split = true;
      };

      group.groupbar = {
        font_family = config.stylix.fonts.sansSerif.name;
        font_size = 14;
        indicator_height = 0;
        height = 20;
        gradients = true;
        gaps_out = 5;
        gaps_in = 2;
        gradient_rounding = 10;
        keep_upper_gap = false;
      };

      workspace = [
        # No gaps or borders when only 1 window exists in the workspace
        # https://wiki.hyprland.org/Configuring/Workspace-Rules/#smart-gaps
        "w[tv1], border:false"
        "f[1], gapsout:0, gapsin:0, border:false"
      ];

      input = {
        kb_layout = "us,gr";
        kb_options = lib.strings.concatStringsSep "," [
          "grp:alt_space_toggle" # Alt-Space to change keyboard layout
          "caps:escape" # Caps Lock is Escape
          "fkeys:basic_13-24" # F13-24 are normal keys, not Xkb/Media keys (for weird key maps)
        ];
        repeat_rate = "56";
        repeat_delay = "200";
        touchpad = {
          natural_scroll = true;
          tap-to-click = true;
          clickfinger_behavior = true;
        };
      };

      decoration.rounding = 10;

      # Fix inconsistent cursor
      #cursor.no_hardware_cursors = true;

      debug.disable_logs = false;
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
