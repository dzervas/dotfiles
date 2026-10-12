{
  config,
  lib,
  pkgs,
  ...
}:
{
  setup.windowManager = "mango";
  imports = [
    ./components/noctalia-shell.nix
    ./components/wayland-fixes.nix
  ];

  home.packages = with pkgs; [
    wev # Input-event debugging, as in the niri configuration
  ];

  gtk.enable = true;
  qt.enable = true;

  wayland.windowManager.mango = {
    enable = true;
    # Retain the upstream environment list and include Noctalia's Mango IPC socket.
    systemd.variables = [
      "DISPLAY"
      "WAYLAND_DISPLAY"
      "XDG_CURRENT_DESKTOP"
      "XDG_SESSION_TYPE"
      "NIXOS_OZONE_WL"
      "XCURSOR_THEME"
      "XCURSOR_SIZE"
      "MANGO_INSTANCE_SIGNATURE"
    ];
    autostart_sh = ''
      ${lib.getExe config.programs.noctalia.package} &
      brave &
      # io.anytype.anytype &
      # zeditor &
      # steam &
      ${config.setup.terminal} &
      org.telegram.desktop &
      dev.vencord.Vesktop &
    '';

    settings = {
      cursor_theme = config.stylix.cursor.name;
      cursor_size = config.stylix.cursor.size;
      sloppy_focus = 1;
      warp_cursor = 1;

      repeat_delay = 200;
      repeat_rate = 56;
      xkb_rules_layout = "us,gr";
      xkb_rules_options = lib.concatStringsSep "," [
        "grp:alt_space_toggle"
        "caps:escape"
        "fkeys:basic_13-24"
      ];
      # TODO: niri's per-window keyboard-layout tracking has no native equivalent.
      tap_to_click = 1;
      trackpad_natural_scrolling = 1;
      trackpad_middle_button_emulation = 1;
      trackpad_scroll_method = 1;
      button_map = 0;

      gap_inner_horizontal = 5;
      gap_inner_vertical = 5;
      gap_outer_horizontal = 5;
      gap_outer_vertical = 5;
      border_px = 0;
      border_radius = 20;
      shadows = 1;
      shadow_only_floating = 0;
      root_color = "0x00000000";
      scroller_proportion_preset = "0.5,0.66";

      # No workspace-sheet overview/shadow/backdrop settings: Mango's overview
      # rearranges window cards. Layer-shell wallpaper stays outside tag animations.
      tag_num = 9;
      tag_rule = [
        "id:*,layout_name:scroller"
        # Monitor-local tags: first M27Q 1=web, 2=work, 3=game;
        # second M27Q 1=term, 2=chat. Specific rules override the wildcard above.
        "id:1,monitor_model:M27Q,monitor_serial:24290B002445,no_hide:1"
        "id:2,monitor_model:M27Q,monitor_serial:24290B002445,no_hide:1"
        "id:3,monitor_model:M27Q,monitor_serial:24290B002445,no_hide:1"
        "id:1,monitor_model:M27Q,monitor_serial:24290B002448,layout_name:grid,no_hide:1"
        "id:2,monitor_model:M27Q,monitor_serial:24290B002448,no_hide:1"
      ];
      # TODO: niri's named workspaces collapse onto numbered tags on a single
      # laptop display. No laptop terminal-tag/layout mapping has been approved.

      monitor_rule = [
        # The manufacturer's name contains a comma, which Mango's parser cannot
        # escape. Model + serial identifies the same displays without truncation.
        "model:M27Q,serial:24290B002445,width:2560,height:1440,refresh:143.856,scale:1,x:0,y:0"
        "model:M27Q,serial:24290B002448,width:2560,height:1440,refresh:143.856,scale:1"
        "model:NE135A1M-NY1,scale:1.67,vrr:1,x:0,y:0"
      ];
      # TODO: desktop on-demand VRR and initial monitor focus are not equivalent
      # to Mango's vrr/primary flags. No fullscreen-VRR or startup-focus substitute.
      # Mango embeds XWayland; niri's xwayland-satellite option does not apply.

      bind = [
        "SUPER,Return,spawn_shell,${config.setup.terminal}"
        "SUPER,c,killclient"
        "SUPER,f,togglefullscreen"
        "SUPER+SHIFT,f,togglefloating"
        # Width actions operate on scroller columns, not the terminal grid.
        "SUPER,h,set_proportion,0.5"
        "SUPER,t,set_proportion,0.33"
        "SUPER+SHIFT,t,set_proportion,0.66"
        "SUPER,l,spawn_shell,${config.setup.lockerInstant}"
        "SUPER,p,spawn_shell,1password --quick-access"
        "SUPER,r,spawn_shell,${config.setup.runner}"
        "SUPER+SHIFT,r,reload_config"
        "SUPER,z,spawn_shell,noctalia msg panel-toggle launcher /zed"

        # TODO: proposed non-equivalent navigation awaits approval. focusstack
        # wraps individual windows rather than niri columns (including stacked ones).
        # "SUPER,Left,focusstack,prev"
        # "SUPER,Right,focusstack,next"
        # "SUPER,Up,focus_window_or_workspace,up"
        # "SUPER,Down,focus_window_or_workspace,down"
        # "SUPER+SHIFT,Left,move_client,left"
        # "SUPER+SHIFT,Right,move_client,right"
        # "SUPER+SHIFT,Up,tagtoleft"
        # "SUPER+SHIFT,Down,tagtoright"
        # "SUPER,Tab,focusmon,prev"
        # "SUPER+SHIFT,Tab,tagmon,prev"
        # prev cycles monitors; it does not return to the previously focused one.
        # No native whole-workspace reorder/move equivalent for SUPER+ALT+Up/Down
        # or SUPER+SHIFT+Comma/Period. These bindings are intentionally absent.
        "SUPER,comma,focusmon,left"
        "SUPER,period,focusmon,right"

        # TODO: SUPER+m / SUPER+SHIFT+m and open-maximized-to-edges need approval.
        # set_proportion,1.0 is not niri's maximize toggle; togglemaximizescreen
        # retains outer gaps and removes a window from its scroller stack.
        # force_fake_maximize only reports maximization; it does not resize.

        "NONE,Print,spawn_shell,noctalia msg screenshot-region"
        # annotate requires an image path; this captures a screen for annotation.
        "SHIFT,Print,spawn_shell,noctalia msg screenshot-annotate"
        "NONE,XF86AudioNext,spawn_shell,playerctl next"
        "NONE,XF86AudioPrev,spawn_shell,playerctl previous"
        "NONE,XF86AudioRaiseVolume,spawn_shell,wpctl set-volume @DEFAULT_AUDIO_SINK@ 5%+"
        "NONE,XF86AudioLowerVolume,spawn_shell,wpctl set-volume @DEFAULT_AUDIO_SINK@ 5%-"
        # Unlike the current niri bindings, toggle is a set-mute argument.
        "NONE,XF86AudioMute,spawn_shell,wpctl set-mute @DEFAULT_AUDIO_SINK@ toggle"
        "NONE,XF86AudioMicMute,spawn_shell,wpctl set-mute @DEFAULT_AUDIO_SOURCE@ toggle"
        "NONE,XF86MonBrightnessUp,spawn_shell,brightnessctl s 10%+"
        "NONE,XF86MonBrightnessDown,spawn_shell,brightnessctl s 10%-"
      ] ++ lib.concatMap (i: [
        "SUPER,${toString i},view,${toString i}"
        "SUPER+SHIFT,${toString i},tag,${toString i}"
      ]) (lib.range 1 9);

      # Play/Pause resolve to one keycode in the default keymap. Match their
      # distinct keysyms, as niri does, instead of creating conflicting binds.
      binds = [
        "NONE,XF86AudioPlay,spawn_shell,playerctl play-pause"
        "NONE,XF86AudioPause,spawn_shell,playerctl play-pause"
      ];

      window_rule = [
        "allow_csd:0"
        "app_id:Steam Settings,is_floating:1"
        "app_id:jadx-gui-JadxGUI,is_floating:1"
        "app_id:org.pulseaudio.pavucontrol,is_floating:1"
        "app_id:org.telegram.desktop,title:Telegram,is_floating:1"
        "app_id:^(steam_app_.*|helldivers2.exe),title:.+,is_fullscreen:1,tags:3,monitor:model:M27Q&&serial:24290B002445"
        "app_id:steam,title:^notificationtoasts_.*,is_floating:1,is_open_silent:1"
        "app_id:^$,title:^$,is_floating:1,is_open_silent:1"
        "app_id:1password,scroller_proportion:0.5"
        "app_id:spotify,scroller_proportion:0.5"

        # Approved difference: route every launch, not just niri's startup window.
        # If the requested monitor is absent, Mango keeps the current/parent monitor
        # but still applies the tag number; this is not niri's named-workspace model.
        "app_id:brave-browser,tags:1,monitor:model:M27Q&&serial:24290B002445"
        "app_id:anytype,tags:2,monitor:model:M27Q&&serial:24290B002445"
        "app_id:dev.zed.Zed,tags:2,monitor:model:M27Q&&serial:24290B002445"
        "app_id:steam,tags:3,monitor:model:M27Q&&serial:24290B002445"
        "app_id:com.mitchellh.ghostty,tags:1,monitor:model:M27Q&&serial:24290B002448"
        "app_id:org.telegram.desktop,tags:2,monitor:model:M27Q&&serial:24290B002448"
        "app_id:vesktop,tags:2,monitor:model:M27Q&&serial:24290B002448"
        "title:flameshot,is_floating:1,is_fullscreen:0"
      ];
      # TODO: do NOT treat shield_when_capture as block-out-from=screen-capture.
      # It shields local viewing too, and legacy wlr-screencopy does not independently
      # activate it. 1Password, Spotify and notification capture privacy is NOT preserved.
      # Bottom-right notification offsets also differ (Mango uses work-area gaps).
      # Global activation_bypass is broader than niri's invalid-serial debug override;
      # neither substitute is enabled without approval.
    };
  };
}
