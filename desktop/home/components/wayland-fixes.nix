{ pkgs, ... }: {
  home = {
    packages = with pkgs; [
      wl-clipboard # wl-copy and wl-paste for copy/paste from stdin / stdout
    ];
    sessionVariables = {
      _JAVA_OPTIONS = "-Dawt.useSystemAAFontSettings=lcd -Dswing.defaultlaf=com.sun.java.swing.plaf.gtk.GTKLookAndFeel";

      MOZ_ENABLE_WAYLAND = "1";
      MOZ_USE_XINPUT2 = "1";

      WLR_DRM_NO_MODIFIERS = "1";
      WLR_NO_HARDWARE_CURSORS = "1";

      _JAVA_AWT_WM_NONREPARENTING = "1";
    };
  };

  services.flatpak.overrides.global = {
    Context.sockets = ["wayland" "!x11" "!fallback-x11"];
    Environment.GDK_BACKEND = "wayland";
  };
}
