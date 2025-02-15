{ config, lib, ... }: let
  cfg = config.setup;
in {
  home.sessionVariables = {
    _JAVA_AWT_WM_NONREPARENTING = "1";
  };

  programs.plasma = {
    enable = true;

    workspace = {
      lookAndFeel = "org.kde.breezedark.desktop";
    };

    panels = [{
        location = "top";
        height = 26;
        widgets = [
          {
            kickoff = {
              sortAlphabetically = true;
              icon = "nix-snowflake-white";
            };
          }
          "org.kde.plasma.kickoff"
          "org.kde.plasma.icontasks"
          "org.kde.plasma.marginsseparator"
          "org.kde.plasma.appmenu"
          "org.kde.plasma.marginsseparator"
          "org.kde.plasma.systemtray"
          "org.kde.plasma.digitalclock"
        ];
    }];

    configFile = {
      "baloofilerc"."Basic Settings"."Indexing-Enabled" = false;
    };

    kscreenlocker = {
      lockOnResume = true;
      timeout = 10;
    };
  };

  xsession.windowManager.i3 = {
    enable = true;
    config = {
      bars = [];
      menu = ""; # KRunner is used
      modifier = "Mod4";
      fonts.size = lib.mkForce 10.0;
      keybindings = {
        "Mod4+Return" = "exec ${cfg.terminal}";
      };
    };
  };
}
