{ config, lib, pkgs, ... }: let
cfg = config.setup;
in {
  imports = [
    ./components/xdg.nix
  ];

  home.sessionVariables = {
    _JAVA_AWT_WM_NONREPARENTING = "1";
  };
  # stylix.targets.kde.enable = false;
  # stylix.targets.qt.enable = false;
  # stylix.targets.qt.platform = false;

  programs.plasma = {
    enable = true;

    workspace = {
      lookAndFeel = "org.kde.breezedark.desktop";
    };

    panels = [{
      location = "top";
      height = 42;
      widgets = [
        # {
          # kickoff = {
            # sortAlphabetically = true;
            # icon = "nix-snowflake-white";
          # };
        # }
        "org.kde.plasma.kickoff"
        "org.kde.plasma.icontasks"
        "org.kde.plasma.marginsseparator"
        "org.kde.plasma.appmenu"
        "org.kde.plasma.marginsseparator"
        "org.kde.plasma.systemtray"
        "org.kde.plasma.digitalclock"
      ];
    }];

    shortcuts = {
      ksmserver = {
        "Lock Session" = [ "ScreenSaver" "Meta+L" ];
      };
      # "services/org.kde.krunner.desktop" = {
        # "_launch" = ["Meta+R"];
      # };
      "services/org.kde.spectacle.desktop" = {
        "RectangularRegionScreenShot" = ["Print"];
      };

      # Madness from the default plasma config
      mediacontrol = {
        mediavolumedown = ["Media volume down"];
        mediavolumeup = ["Media volume up"];
        nextmedia = ["Media Next" "Media playback next"];
        previousmedia = ["Media Previous" "Media playback previous"];
        playmedia = ["Play media playback"];
        playpausemedia = ["Media Play" "Play/Pause media playback"];
        pausemedia = ["Media Pause" "Pause media playback"];
        stopmedia = ["Stop media" "Stop media playback"];
      };
      kmix = {
        decrease_volume = ["Volume Down" "Decrease Volume"];
        increase_volume = ["Volume Up" "Increase Volume"];
        mute = ["Volume Mute" "Mute"];
        decrease_microphone_volume = ["Microphone Volume Down" "Decrease Microphone Volume"];
        increase_microphone_volume = ["Microphone Volume Up" "Increase Microphone Volume"];
        mic_mute = ["Microphone Mute" "Mute Microphone"];
      };
    };

    configFile = {
      "baloofilerc"."Basic Settings"."Indexing-Enabled" = false;
    };
    overrideConfigFiles = [
      "kglobalshortcutsrc"
    ];
  };

# https://github.com/danth/stylix/issues/835#issuecomment-2646316101
# qt = {
# enable = true;
# platformTheme.package = with pkgs.kdePackages; [
# plasma-integration
# I don't remember why I put this is here, maybe it fixes the theme of the system setttings
# systemsettings
# qtstyleplugin-kvantum
# ];
#style = {
#    package = pkgs.kdePackages.breeze;
#    name = lib.mkForce "Breeze";
#};
# };
#systemd.user.sessionVariables = { QT_QPA_PLATFORMTHEME = lib.mkForce "kde"; };

  xsession.windowManager.i3 = {
    enable = true;
    config = let
      modifier = "Mod4";
    in {
      inherit modifier;

      bars = [];
      menu = ""; # KRunner is used
      fonts.size = lib.mkForce 10.0;
      keybindings = {
        # Basic actions
        "${modifier}+c" = "kill";
        "${modifier}+f" = "fullscreen";
        "${modifier}+Down" = "focus prev sibling";
        "${modifier}+Up" = "focus next sibling";
        "${modifier}+Shift+e" = "exec i3-nagbar -t warning -m 'You pressed the exit shortcut. Do you really want to exit i3?' -b 'Yes, exit i3' 'i3-msg exit'";
        "${modifier}+Shift+f" = "floating toggle";
        "${modifier}+Shift+r" = "restart";
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
        "${modifier}+p" = "exec 1password --quick-access";
        "${modifier}+r" = "exec krunner";

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
      };
    };

    extraConfig = ''
      font pango:Iosevka 10
      hide_edge_borders both
      show_marks yes

      for_window [urgent="latest"] focus
      for_window [class=.*] inhibit_idle fullscreen
      for_window [title=".*"] title_format %title

      for_window [class="(?i)(?:blueman-manager|azote|gnome-disks)"] floating enable
      for_window [class="(?i)(?:pavucontrol|nm-connection-editor|gsimplecal|galculator)"] floating enable
      for_window [class="(?i)(?:firefox|chromium)"] border none
      for_window [class="^firefox$" title="^[Pp]icture-in-[Pp]icture$"] floating enable, resize set 1280 720, move position center
      for_window [title="(?i)(?:copying|deleting|moving)"] floating enable

      for_window [class="^zenity$"] floating enable
      for_window [class="^[Pp]inentry-.*"] floating enable
      for_window [class="^com-install4j-runtime-launcher-UnixLauncher$"] floating enable
      for_window [class="^net-portswigger-burp-browser-BurpBrowserServer$"] floating enable
      for_window [class="^burp-StartBurp$"] floating enable
      for_window [class="^torbrowser-launcher$"] floating enable
      for_window [class="^1[Pp]assword$"] floating enable
      for_window [title="^Wine System Tray$"] floating enable, move scratchpad
      for_window [title="^ContentDialogOverlayWindow$"] floating enable, focus
      for_window [title="^Steam Settings$"] floating enable, focus
      for_window [title="^Open$" class="^com.vector35.binaryninja$"] floating enable, focus
      for_window [class="^jadx-gui-JadxGUI$"] floating enable, focus

      # Try to kill the wallpaper set by Plasma (it takes up the entire workspace and hides everythiing)
      #for_window [class="^plasmashell$"] kill

      # Avoid tiling popups, dropdown windows from plasma
      # for the first time, manually resize them, i3 will remember the setting for floating windows
      for_window [class="plasmashell"] floating enable;
      for_window [class="Plasma"] floating enable; border none
      for_window [title="plasma-desktop"] floating enable; border none
      for_window [title="win7"] floating enable; border none
      for_window [class="krunner"] floating enable; border none
      for_window [class="Kmix"] floating enable; border none
      for_window [class="Klipper"] floating enable; border none
      for_window [class="Plasmoidviewer"] floating enable; border none
      # for_window [class="plasmashell" window_type="notification"] floating enable, border none, move right 590px, move up 650px
      # for_window [class="plasmashell" window_type="notification"] floating enable, border none, move position 1580px 35px
      no_focus [class="plasmashell" window_type="notification"]
    '';
  };

  systemd.user.services.plasma-kwin_x11.Service.ExecStart = "${config.xsession.windowManager.i3.package}/bin/i3";
}
