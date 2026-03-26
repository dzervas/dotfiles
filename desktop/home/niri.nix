{ config, lib, pkgs, ... }:
{
  setup.windowManager = "niri";
  imports = [
    ./components/noctalia-shell.nix
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
        "Mod+H".action.set-column-width = "50%";
        "Mod+M".action.maximize-column = [ ];
        "Mod+Shift+M".action.maximize-window-to-edges = [ ];
        "Mod+L".action.spawn-sh = config.setup.lockerInstant;
        "Mod+P".action.spawn-sh = "1password --quick-access";
        "Mod+R".action.spawn-sh = config.setup.runner;
        "Mod+Shift+R".action.spawn-sh = "niri msg action load-config-file";
        "Mod+T".action.set-column-width = "33%";
        "Mod+Shift+T".action.set-column-width = "66%";
        "Mod+Z".action.spawn-sh = "noctalia-shell ipc call plugin:zed-provider toggle";

        "Mod+Left".action.focus-column-left-or-last = [ ];
        "Mod+Right".action.focus-column-right-or-first = [ ];
        "Mod+Up".action.focus-window-or-workspace-up = [ ];
        "Mod+Down".action.focus-window-or-workspace-down = [ ];
        "Mod+Alt+Up".action.move-workspace-up = [ ];
        "Mod+Alt+Down".action.move-workspace-down = [ ];
        "Mod+Shift+Left".action.move-column-left = [ ];
        "Mod+Shift+Right".action.move-column-right = [ ];
        "Mod+Shift+Up".action.move-window-to-workspace-up = [ ];
        "Mod+Shift+Down".action.move-window-to-workspace-down = [ ];

        "Mod+Comma".action.focus-monitor-left = [ ];
        "Mod+Period".action.focus-monitor-right = [ ];
        "Mod+Tab".action.focus-monitor-previous = [ ];
        "Mod+Shift+Comma".action.move-window-to-monitor-left = [ ];
        "Mod+Shift+Period".action.move-window-to-monitor-right = [ ];
        "Mod+Shift+Tab".action.move-window-to-monitor-previous = [ ];

        # "Print".action.spawn-sh = "flameshot gui";
        # Flameshot workaround by https://github.com/niri-wm/niri/discussions/1737
        "Print".action.spawn-sh = ''${pkgs.grim}/bin/grim -t ppm -g "$(${pkgs.slurp}/bin/slurp -d)" - | ${pkgs.satty}/bin/satty -f - --initial-tool=arrow --copy-command=wl-copy --actions-on-escape="save-to-clipboard,exit" --brush-smooth-history-size=5 --disable-notifications'';

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

        "Mod+1".action.focus-workspace = 1;
        "Mod+2".action.focus-workspace = 2;
        "Mod+3".action.focus-workspace = 3;
        "Mod+4".action.focus-workspace = 4;
        "Mod+5".action.focus-workspace = 5;
        "Mod+6".action.focus-workspace = 6;
        "Mod+7".action.focus-workspace = 7;
        "Mod+8".action.focus-workspace = 8;
        "Mod+9".action.focus-workspace = 9;

        "Mod+Shift+1".action.move-window-to-workspace = 1;
        "Mod+Shift+2".action.move-window-to-workspace = 2;
        "Mod+Shift+3".action.move-window-to-workspace = 3;
        "Mod+Shift+4".action.move-window-to-workspace = 4;
        "Mod+Shift+5".action.move-window-to-workspace = 5;
        "Mod+Shift+6".action.move-window-to-workspace = 6;
        "Mod+Shift+7".action.move-window-to-workspace = 7;
        "Mod+Shift+8".action.move-window-to-workspace = 8;
        "Mod+Shift+9".action.move-window-to-workspace = 9;
      };

      layout = {
        gaps = 5;
        preset-column-widths = [
          { proportion = 0.5; }
          { proportion = 0.66; }
        ];

        background-color = "transparent";

        border.enable = false;
        shadow.enable = true;
        focus-ring = {
          # Broken due to ghostty https://github.com/ghostty-org/ghostty/issues/3009
          enable = false;
          width = 2;
        };
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

      debug.honor-xdg-activation-with-invalid-serial = {};
      window-rules = [
        {
          # Noctila provided
          geometry-corner-radius = let radius = 20.0;
          in {
            top-left = radius;
            top-right = radius;
            bottom-left = radius;
            bottom-right = radius;
          };
          # Clip window contents to the rounded corners
          clip-to-geometry = true;
        }
        {
          matches = [
            { app-id = "Steam Settings"; }
            { app-id = "jadx-gui-JadxGUI"; }
            { app-id = "org.pulseaudio.pavucontrol"; }
            { app-id = "org.telegram.desktop"; title = "Telegram"; }
          ];
          open-floating = true;
        }
        {
          matches = [
            { app-id = "brave-browser"; }
            { app-id = "com.mitchellh.ghostty"; }
          ];
          open-maximized = false;
          # open-maximized-to-edges = true;
        }
        {
          matches = [{ app-id= "steam"; title = "^notificationtoasts_.*"; }];

          clip-to-geometry = true;
          open-floating = true;
          open-focused = false;
          block-out-from = "screen-capture";
          focus-ring.enable = false;
          default-floating-position = {
            x = 0;
            y = 0;
            relative-to = "bottom-right";
          };
        }
        {
          matches = [
            { app-id = "1password"; }
            { app-id = "spotify"; }
          ];

          default-column-width.proportion = 0.5;
          open-maximized = false;
          # open-maximized-to-edges = false;
          block-out-from = "screen-capture";
        }
      ];

      overview.workspace-shadow.enable = false;
      layer-rules = [{
        # Make the wallpaper stationary
        matches = [{ namespace = "^wallpaper$"; }];
        place-within-backdrop = true;
      }];
    };
  };
}
