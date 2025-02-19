{ config, lib, pkgs, ... }: let
  cfg = config.setup;
in {
  imports = [
    ./components/xdg.nix
  ];

  home.sessionVariables = {
    _JAVA_AWT_WM_NONREPARENTING = "1";
  };
  stylix.targets.kde.enable = false;

 programs.plasma = {
   enable = true;

  #  workspace = {
  #    lookAndFeel = "org.kde.breezedark.desktop";
  #  };

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
#
#  # https://github.com/danth/stylix/issues/835#issuecomment-2646316101
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
#
#  xsession.windowManager.i3 = {
#    # enable = true;
#    config = {
#      bars = [];
#      menu = ""; # KRunner is used
#      modifier = "Mod4";
#      fonts.size = lib.mkForce 10.0;
#      keybindings = {
#        "Mod4+Return" = "exec ${cfg.terminal}";
#      };
#    };
#  };
}
