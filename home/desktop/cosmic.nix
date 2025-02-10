{ config, lib, pkgs, ... }: let
  cfg = config.setup;
  modifier = "Mod4";
  mkRonValue = type: value: { inherit value; __type = type; };
  mkRonVariant = variant: { inherit variant; __type = "enum"; };
  mkRonVarVal = variant: value: { inherit variant value; __type = "enum"; };
in {
  # Problems:
  # - No per-output pinned workspaces (1 & 3 on left, 2 & 4 on right)
  # - Auto-lock doesn't work
  # - Screenshot utility doesn't work
  # - Window gaps can't be configured (from GUI only?)
  # - Window decorations can't be disabled
  # - No single-window mode (tabbed layout)
  # - No window rules (floating/fullscreen/etc.)

  wayland.desktopManager.cosmic = {
    enable = true;
    compositor = {
      active_hint = false;
      autotile = true;
      autotile_behavior = mkRonVariant "PerWorkspace";
      cursor_follows_focus = true;
      focus_follows_cursor = true;
      focus_follows_cursor_delay = 100;
      workspaces = {
        workspace_layout = mkRonVariant "Horizontal";
        workspace_mode = mkRonVariant "OutputBound";
      };
      xkb_config = {
        model = "pc104";
        layout = "us,gr";
        options = mkRonValue "optional" "grp:alt_space_toggle,caps:escape";
        repeat_rate = 56;
        repeat_delay = 200;
        rules = "";
        variant = "qwerty";
      };
    };
    idle = {
      screen_off_time = mkRonValue "optional" 300000;
      suspend_on_ac_time = null;
      suspend_on_battery_time = mkRonValue "optional" 600000;
    };
    wallpapers = [{
      source = mkRonVarVal "Path" [config.stylix.image];
      output = "all";
      filter_by_theme = false;
      filter_method = mkRonVariant "Lanczos";
      rotation_frequency = 600;
      sampling_method = mkRonVariant "Random";
      scaling_mode = mkRonVariant "Zoom";
    }];
    panels = [{
      name = "Panel";
      anchor = mkRonVariant "Top";
      anchor_gap = false;
      size = mkRonVariant "XS";
      output = mkRonVariant "All";
      plugins_center = mkRonValue "optional" [ "com.system76.CosmicAppletTime" ];
      plugins_wings = mkRonValue "optional" (mkRonValue "tuple" [
        [
          "com.system76.CosmicAppletPower"
          "com.system76.CosmicAppletWorkspaces"
          "com.system76.CosmicPanelWorkspacesButton"
          "com.system76.CosmicPanelAppButton"
        ]
        [
          "com.system76.CosmicAppletInputSources"
          "com.system76.CosmicAppletStatusArea"
          "com.system76.CosmicAppletNetwork"
          "com.system76.CosmicAppletBluetooth"
          "com.system76.CosmicAppletAudio"
          "com.system76.CosmicAppletBattery"
          "com.system76.CosmicAppletNotifications"
          "com.system76.CosmicAppletTiling"
        ]
      ]);
    }];
    shortcuts = [
      { key = "Super+L"; action = mkRonVarVal "System" [(mkRonVariant "LockScreen")]; }
      { key = "Super+P"; action = mkRonVarVal "Spawn" ["1password --quick-access"]; }
      { key = "Super+R"; action = mkRonVarVal "System" [(mkRonVariant "Launcher")]; }
      { key = "Super+Return"; action = mkRonVarVal "Spawn" ["alacritty"]; }

      # Navigation
      { key = "Super+Tab"; action = mkRonVariant "LastWorkspace"; }

      # Window management
      { key = "Super+C"; action = mkRonVariant "Close"; }
      { key = "Super+D"; action = mkRonVariant "ToggleOrientation"; }
      { key = "Super+F"; action = mkRonVariant "Maximize"; }
      { key = "Super+Shift+F"; action = mkRonVariant "ToggleWindowFloating"; }
      { key = "Super+T"; action = mkRonVariant "ToggleStacking"; }

      # Disable some default shortcuts
      { key = "Super"; action = mkRonVariant "Disable"; }
      { key = "Super+A"; action = mkRonVariant "Disable"; }
      { key = "Super+B"; action = mkRonVariant "Disable"; }
      { key = "Super+G"; action = mkRonVariant "Disable"; }
      { key = "Super+H"; action = mkRonVariant "Disable"; }
      { key = "Super+I"; action = mkRonVariant "Disable"; }
      { key = "Super+J"; action = mkRonVariant "Disable"; }
      { key = "Super+K"; action = mkRonVariant "Disable"; }
      { key = "Super+M"; action = mkRonVariant "Disable"; }
      { key = "Super+O"; action = mkRonVariant "Disable"; }
      { key = "Super+Q"; action = mkRonVariant "Disable"; }
      { key = "Super+Shift+R"; action = mkRonVariant "Disable"; }
      { key = "Super+S"; action = mkRonVariant "Disable"; }
      { key = "Super+U"; action = mkRonVariant "Disable"; }
      { key = "Super+W"; action = mkRonVariant "Disable"; }
      { key = "Super+Y"; action = mkRonVariant "Disable"; }
      { key = "Super+0"; action = mkRonVariant "Disable"; }
      { key = "Super+Escape"; action = mkRonVariant "Disable"; }
      { key = "Super+Shift+Escape"; action = mkRonVariant "Disable"; }
      { key = "Super+Slash"; action = mkRonVariant "Disable"; }
      { key = "Alt+Tab"; action = mkRonVariant "Disable"; }
      { key = "Alt+Shift+Tab"; action = mkRonVariant "Disable"; }
      { key = "Super+Shift+Tab"; action = mkRonVariant "Disable"; }
      { key = "Super+Shift+Up"; action = mkRonVariant "Disable"; }
      { key = "Super+Ctrl+Alt+Up"; action = mkRonVariant "Disable"; }
      { key = "Super+Shift+Down"; action = mkRonVariant "Disable"; }
      { key = "Super+Ctrl+Alt+Down"; action = mkRonVariant "Disable"; }
      { key = "Super+Shift+Left"; action = mkRonVariant "Disable"; }
      { key = "Super+Ctrl+Alt+Left"; action = mkRonVariant "Disable"; }
      { key = "Super+Shift+Right"; action = mkRonVariant "Disable"; }
      { key = "Super+Ctrl+Alt+Right"; action = mkRonVariant "Disable"; }
      { key = "Super+Shift+H"; action = mkRonVariant "Disable"; }
      { key = "Super+Ctrl+Alt+H"; action = mkRonVariant "Disable"; }
      { key = "Super+Shift+J"; action = mkRonVariant "Disable"; }
      { key = "Super+Ctrl+Alt+J"; action = mkRonVariant "Disable"; }
      { key = "Super+Shift+K"; action = mkRonVariant "Disable"; }
      { key = "Super+Ctrl+Alt+K"; action = mkRonVariant "Disable"; }
      { key = "Super+Shift+L"; action = mkRonVariant "Disable"; }
      { key = "Super+Ctrl+Alt+L"; action = mkRonVariant "Disable"; }
    ];
  };
}
