{ ... }: {
  # To update shortcuts: nix-shell -p desktop-file-utils --run "update-desktop-database -v"
  services.flatpak = {
    enable = true;
    update.auto.enable = true;
    uninstallUnmanaged = true;
    packages = [
      "com.prusa3d.PrusaSlicer"
      # "com.slack.Slack"
      # "com.spotify.Client"
      "com.valvesoftware.Steam"
      "com.github.tchx84.Flatseal"
      "md.obsidian.Obsidian"
      "org.chromium.Chromium"
      "org.onlyoffice.desktopeditors"
    ];

    overrides = {
      # global.Environment.GTK_THEME = "Adwaita:dark";
      global.Context = {
        filesystems = [
          "xdg-config/gtk-3.0:ro"
          "xdg-config/gtk-4.0:ro"
          "xdg-download"
          "/run/dbus/system_bus_socket"
          "!host:reset"
          "!host-os:reset"
          "!host-etc:reset"
          "!home:reset"
        ];
        devices = [ "!all:reset" ];
      };

      "com.prusa3d.PrusaSlicer" = {
        Context.sockets = [ "x11" ];
        Environment.PRUSA_SLICER_DARK_THEME = "true";
      };
      "com.valvesoftware.Steam".Context = {
        sockets = ["x11"];
        devices = [ "all" ];
      };
      "org.onlyoffice.desktopeditors".Context.sockets = ["x11"];
      "md.obsidian.Obsidian".Context.filesystems = [ "xdg-documents/Obsidian" ];
    };
  };

  home.file.".var/app/org.chromium.Chromium/config/chromium-flags.conf".text = ''
    --ozone-platform=wayland
  '';
}
