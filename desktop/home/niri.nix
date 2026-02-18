{
  config,
  lib,
  pkgs,
  ...
}:
{
  setup.windowManager = "niri";
  imports = [
    ./components/swayidle.nix
    ./components/swaylock.nix
    ./components/rofi.nix
    ./components/swaync.nix
    ./components/trays.nix
    ./components/waybar.nix
    ./components/wayland-fixes.nix
  ];

  home.packages = with pkgs; [ grim ]; # For flameshot

  gtk.enable = true;
  qt.enable = true;

  services = {
    flameshot.settings.General = {
      disabledGrimWarning = true;
      useGrimAdapter = true; # Requires grim!
    };
  };

  programs.niri = {
    settings = {
      prefer-no-csd = true;
      cursor.size = config.stylix.cursor.size;
      xwayland-satellite = {
        enable = true;
        path = lib.getExe pkgs.xwayland-satellite-unstable;
      };

      binds = {
        "Mod+Return".action.spawn-sh = config.setup.terminal;

        "Mod+C".action.close-window = [ ];
        "Mod+F".action.fullscreen-window = [ ];
        "Mod+Shift+F".action.toggle-window-floating = [ ];
        "Mod+M".action.maximize-column = [ ];
        "Mod+Shift+M".action.maximize-window-to-edges = [ ];
        "Mod+L".action.spawn-sh = config.setup.lockerInstant;
        "Mod+P".action.spawn-sh = "1password --quick-access";
        "Mod+Shift+R".action.spawn-sh = "niri msg action load-config-file";
        "Mod+R".action.spawn-sh = config.setup.runner;

        "Mod+Left".action.focus-column-left-or-last = [ ];
        "Mod+Right".action.focus-column-right-or-first = [ ];
        "Mod+Shift+Left".action.move-column-left = [ ];
        "Mod+Shift+Right".action.move-column-right = [ ];

        "Mod+Comma".action.focus-monitor-left = [ ];
        "Mod+Period".action.focus-monitor-right = [ ];
        "Mod+Tab".action.focus-monitor-previous = [ ];
        "Mod+Shift+Comma".action.move-window-to-monitor-left = [ ];
        "Mod+Shift+Period".action.move-window-to-monitor-right = [ ];
        "Mod+Shift+Tab".action.move-window-to-monitor-previous = [ ];

        "Print".action.spawn-sh = "flameshot gui";

        "XF86AudioPlay".action.spawn-sh = "playerctl play-pause";
        "XF86AudioPause".action.spawn-sh = "playerctl play-pause";
        "XF86AudioNext".action.spawn-sh = "playerctl next";
        "XF86AudioPrev".action.spawn-sh = "playerctl previous";

        "XF86AudioRaiseVolume".action.spawn-sh = "wpctl set-volume @DEFAULT_AUDIO_SINK@ 5%+";
        "XF86AudioLowerVolume".action.spawn-sh = "wpctl set-volume @DEFAULT_AUDIO_SINK@ 5%-";
        "XF86AudioMute".action.spawn-sh = "wpctl set-volume @DEFAULT_AUDIO_SINK@ toggle";
        "XF86AudioMicMute".action.spawn-sh = "wpctl set-volume @DEFAULT_AUDIO_SOURCE@ toggle";
        "XF86MonBrightnessUp".action.spawn-sh = "brightnessctl s 10%+";
        "XF86MonBrightnessDown".action.spawn-sh = "brightnessctl s 10%-";

        "Mod+1".action.focus-column = 1;
        "Mod+2".action.focus-column = 2;
        "Mod+3".action.focus-column = 3;
        "Mod+4".action.focus-column = 4;
        "Mod+5".action.focus-column = 5;
        "Mod+6".action.focus-column = 6;
        "Mod+7".action.focus-column = 7;
        "Mod+8".action.focus-column = 8;
        "Mod+9".action.focus-column = 9;
      };

      input = {
        focus-follows-mouse.enable = true;
        warp-mouse-to-focus.enable = true;

        keyboard = {
          repeat-delay = 200;
          repeat-rate = 56;
          track-layout = "window";
          xkb = {
            layout = "us,gr";
            options = lib.strings.concatStringsSep "," [
              "grp:alt_space_toggle" # Alt-Space to change keyboard layout
              "caps:escape" # Caps Lock is Escape
              "fkeys:basic_13-24" # F13-24 are normal keys, not Xkb/Media keys (for weird key maps)
            ];
          };
        };
        touchpad = {
          middle-emulation = true;
          natural-scroll = true;
          scroll-method = "two-finger";
          tap = true;
          tap-button-map = "left-right-middle";
        };
      };
      outputs = {
        "GIGA-BYTE TECHNOLOGY CO. LTD. M27Q 24290B002445" = {
          enable = true;
          focus-at-startup = true;
          variable-refresh-rate = true;
          scale = 1;
          position = {
            x = 0;
            y = 0;
          };
        };
        "GIGA-BYTE TECHNOLOGY CO. LTD. M27Q 24290B002448" = {
          enable = true;
          variable-refresh-rate = true;
          scale = 1;
        };
        "BOE NE135A1M-NY1" = {
          # Laptop built-in display
          enable = true;
          focus-at-startup = true;
          variable-refresh-rate = true;
          scale = 1.67;
          position = {
            x = 0;
            y = 0;
          };
        };
      };

      window-rules = [
        {
          matches = [
            { app-id = "Steam Settings"; }
            { app-id = "jadx-gui-JadxGUI"; }
            { app-id = "org.pulseaudio.pavucontrol"; }
            { app-id = "org.telegram.desktop"; title = "Telegram"; }
          ];
          open-floating = true;
        }
      ];
    };
  };
}
