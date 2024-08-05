{ config, lib, pkgs, ... }: let
  cfg = config.setup;
  modifier = "Mod4";
in {
  imports = [
    ./components/kanshi.nix
    ./components/rofi.nix
    ./components/swayidle.nix
    ./components/swaylock.nix
    ./components/trays.nix
    ./components/waybar.nix
    ./components/xdg.nix
  ];

  services.swaync.enable = true;

  home.packages = with pkgs; [
    swaykbdd

    # screenshot functionality
    grim
    slurp
    swappy

    wl-clipboard # wl-copy and wl-paste for copy/paste from stdin / stdout
    brightnessctl
    playerctl
  ];

  gtk = {
    enable = true;
    iconTheme = {
      package = pkgs.adwaita-icon-theme;
      name = "Adwaita";
    };
  };
  qt.enable = true;

  services.flatpak.overrides.global = {
    Context.sockets = ["wayland" "!x11" "!fallback-x11"];
    Environment.GDK_BACKEND = "wayland";
  };

  home.sessionVariables = {
    _JAVA_OPTIONS = "-Dawt.useSystemAAFontSettings=lcd -Dswing.defaultlaf=com.sun.java.swing.plaf.gtk.GTKLookAndFeel";

    MOZ_ENABLE_WAYLAND = "1";
    MOZ_USE_XINPUT2 = "1";

    WLR_DRM_NO_MODIFIERS = "1";
  };

  wayland.windowManager.sway = {
    enable = true;

    systemd = {
      enable = true;
      xdgAutostart = true;
    };

    wrapperFeatures.gtk = true;

    config = {
      fonts.size = lib.mkForce 10.0;
      startup = [
        { command = "systemd-notify --ready || true"; }
        { command = "1password --silent"; }
        { command = cfg.terminal; }
        { command = cfg.browser; }
        { command = "swaykbdd"; }
        { command = "systemctl --user restart kanshi"; always = true; }
        # Fix firefox as default browser
        { command = "systemctl --user import-environment PATH && systemctl --user restart xdg-desktop-portal.service"; always = true; }
      ];
      bars = [{
        position = "top";
        command = cfg.bar;
      }];
      input = {
        "type:keyboard" = {
          xkb_layout = "us,gr";
          xkb_options = "grp:alt_space_toggle,caps:escape";
          repeat_rate = "56";
          repeat_delay = "200";
          xkb_capslock = "disabled";
          xkb_numlock = "disabled";
        };
        "type:touchpad" = {
          tap = "enabled";
          natural_scroll = "enabled";
          dwt = "enabled";
        };
      };

      output = {
        "VGA-1" = {
          # VirtualBox
          mode = "1920x1080";
          scale = "1";
        };
      };

      window.titlebar = false;
      floating.titlebar = false;

      # Key bindings
      floating.modifier = modifier;
      keybindings = {
        # Basic actions
        "${modifier}+c" = "kill";
        "${modifier}+f" = "fullscreen";
        "${modifier}+z" = "scratchpad show";
        "${modifier}+Grave" = "scratchpad show";
        "${modifier}+Down" = "focus left";
        "${modifier}+Up" = "focus right";
        "${modifier}+Shift+e" = "exec swaynag -t warning -m 'You pressed the exit shortcut. Do you really want to exit sway? This will end your Wayland session.' -b 'Yes, exit sway' 'swaymsg exit'";
        "${modifier}+Shift+f" = "floating toggle";
        "${modifier}+Shift+r" = "reload";
        "${modifier}+Shift+z" = "move scratchpad";
        "${modifier}+Shift+Grave" = "move scratchpad";
        "${modifier}+Shift+Up" = "move right";
        "${modifier}+Shift+Down" = "move left";
        "${modifier}+Shift+Left" = "move container to workspace left";
        "${modifier}+Shift+Right" = "move container to workspace right";

        # Layout
        "${modifier}+h" = "split h";
        "${modifier}+v" = "split v";
        "${modifier}+e" = "layout toggle split";
        "${modifier}+s" = "layout stacking";
        "${modifier}+t" = "layout tabbed";

        # Core applications
        "${modifier}+Return" = "exec ${cfg.terminal}";
        "${modifier}+l" = "exec '${cfg.locker}'";
        "${modifier}+p" = "exec 1password --quick-access";
        "${modifier}+r" = "exec ${cfg.runner}";

        # Switch to workspace
        "${modifier}+Left" = "workspace prev_on_output";
        "${modifier}+Right" = "workspace next_on_output";
        "${modifier}+Tab" = "workspace back_and_forth";

        "${modifier}+comma" = "focus output left";
        "${modifier}+period" = "focus output right";

        "${modifier}+1" = "workspace number 1";
        "${modifier}+2" = "workspace number 2";
        "${modifier}+3" = "workspace number 3";
        "${modifier}+4" = "workspace number 4";
        "${modifier}+5" = "workspace number 5";
        "${modifier}+6" = "workspace number 6";
        "${modifier}+7" = "workspace number 7";
        "${modifier}+8" = "workspace number 8";

        # Move focused container to workspace
        "${modifier}+Shift+comma" = "move workspace to output left";
        "${modifier}+Shift+period" = "move workspace to output right";
        "${modifier}+Shift+Tab" = "move container to workspace back_and_forth";

        "${modifier}+Shift+1" = "move container to workspace number 1";
        "${modifier}+Shift+2" = "move container to workspace number 2";
        "${modifier}+Shift+3" = "move container to workspace number 3";
        "${modifier}+Shift+4" = "move container to workspace number 4";
        "${modifier}+Shift+5" = "move container to workspace number 5";
        "${modifier}+Shift+6" = "move container to workspace number 6";
        "${modifier}+Shift+7" = "move container to workspace number 7";
        "${modifier}+Shift+8" = "move container to workspace number 8";

        # Screenshots
        "Print" = "exec 'grim -g \"$(slurp)\" - | swappy -f -'";
        "Shift+Print" = "exec 'grim -g \"$(swaymsg -t get_tree | jq -r '.. | (.nodes? // empty)[] | select(.pid and .visible) | .rect | \\\"\\(.x),\\(.y) \\(.width)x\\(.height)\\\"')\" - | swappy -f -'";
        "Ctrl+Print" = "exec 'grim -g \"$(slurp -or)\" - | swappy -f -'";

        XF86AudioRaiseVolume = "exec 'wpctl set-volume @DEFAULT_AUDIO_SINK@ 5%+'";
        XF86AudioLowerVolume = "exec 'wpctl set-volume @DEFAULT_AUDIO_SINK@ 5%-'";
        XF86AudioMute = "exec 'wpctl set-mute'";
        XF86AudioPlay = "exec 'playerctl play-pause'";
        XF86AudioNext = "exec 'playerctl next'";
        XF86AudioPrev = "exec 'playerctl previous'";

        XF86MonBrightnessUp = "exec 'light -A 10'";
        XF86MonBrightnessDown = "exec 'light -U 10'";
      };
    };
    extraConfig = ''
      default_border none
      default_floating_border none
      default_orientation horizontal
      focus_on_window_activation focus
      hide_edge_borders --i3 both
      popup_during_fullscreen smart

      set $laptop eDP-1
      bindswitch lid:on output $laptop disable
      bindswitch lid:off output $laptop enable


      for_window [urgent="latest"] focus
      for_window [class=.*] inhibit_idle fullscreen
      for_window [title="."] title_format %title


      for_window [app_id="(?i)(?:blueman-manager|azote|gnome-disks)"] floating enable
      for_window [app_id="(?i)(?:pavucontrol|nm-connection-editor|gsimplecal|galculator)"] floating enable
      for_window [app_id="(?i)(?:firefox|chromium)"] border none
      for_window [app_id="^firefox$" title="^[Pp]icture-in-[Pp]icture$"] floating enable, resize set 1280 720, move position center
      for_window [title="(?i)(?:copying|deleting|moving)"] floating enable

      for_window [app_id="^zenity$"] floating enable
      for_window [app_id="^[Pp]inentry-.*"] floating enable
      for_window [app_id="^com-install4j-runtime-launcher-UnixLauncher$"] floating enable
      for_window [app_id="^net-portswigger-burp-browser-BurpBrowserServer$"] floating enable
      for_window [app_id="^burp-StartBurp$"] floating enable
      for_window [app_id="^torbrowser-launcher$"] floating enable
      for_window [class="^1[Pp]assword$"] floating enable
      for_window [title="^Wine System Tray$"] floating enable, move scratchpad
      for_window [title="^ContentDialogOverlayWindow$"] floating enable, focus
      for_window [title="^Steam Settings$"] floating enable, focus
    '';
    extraOptions = [ "--unsupported-gpu" ];
  };
}
