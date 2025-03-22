{ config, inputs, pkgs, ... }: {
  setup.windowManager = "hyprland";
  imports = [
    ./components/rofi.nix
    ./components/trays.nix
    ./components/waybar.nix
    ./components/wayland-fixes.nix
  ];

  services.dunst.enable = true;
  home.pointerCursor.hyprcursor = {
    enable = true;
    size = 24;
  };

  wayland.windowManager.hyprland = {
    enable = true;
    settings = {
      "$mod" = "SUPER";
      bind = [
        "$mod, Return, exec, alacritty"
        "$mod, C, killactive"
        "$mod, E, exec, hyprctl keyword general:layout 'dwindle'"
        "$mod, T, exec, hyprctl keyword general:layout 'master'"
        "$mod, F, fullscreen"
        "$mod, G, togglegroup"
        "$mod, R, exec, ${config.setup.runner}"
        "$mod, P, exec, 1password --quick-access"
        "$mod, L, exec, hyprlock"
        "$mod+Shift, F, togglefloating"
        "$mod+Shift, R, exec, hyprctl reload"
        "$mod, Left, workspace, m-1"
        "$mod+Shift, Left, movetoworkspacesilent, m-1"
        "$mod, Right, workspace, m+1"
        "$mod+Shift, Right, movetoworkspacesilent, m+1"
        "$mod, Up, cyclenext, tiled"
        "$mod+Shift, Up, swapnext, tiled"
        "$mod, Down, cyclenext, tiled, prev"
        "$mod+Shift, Down, swapnext, tiled, prev"

        "$mod, Tab, workspace, previous"
        "$mod, Comma, focusmonitor, +1"
        "$mod+Shift, Comma, movecurrentworkspacetomonitor, +1"
        "$mod, Period, focusmonitor, -1"
        "$mod+Shift, Period, movecurrentworkspacetomonitor, -1"
        ", Print, exec, grimblast copy area"
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

      monitor = [
        "desc:Dell Inc. DELL S3422DWG B3F7KK3, preferred, 1080x492, 1.25"
        "desc:Dell Inc. DELL P2419H C49BFZ2, preferred, 0x0, 1, transform, 1"
      ];

      # Layouts
      master = {
        new_status = "master";
      };
      dwindle = {
        pseudotile = true;
        preserve_split = true;
      };

      workspace = [
        # No gaps when only 1 window exists in the workspace
        # https://wiki.hyprland.org/Configuring/Workspace-Rules/#smart-gaps
        "w[tv1], gapsout:0, gapsin:0"
        "f[1], gapsout:0, gapsin:0"
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
    };
    plugins = [
      inputs.hyprland-plugins.packages.${pkgs.stdenv.hostPlatform.system}.hyprbars
    ];

    # set the Hyprland and XDPH packages to null to use the ones from the NixOS module
    package = null;
    portalPackage = null;

    # https://wiki.hyprland.org/Useful-Utilities/Systemd-start/#installation
    systemd.enable = false;
  };
}
