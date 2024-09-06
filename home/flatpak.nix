_: {
  # To update shortcuts: nix-shell -p desktop-file-utils --run "update-desktop-database -v"
  services.flatpak = {
    enable = true;
    update.auto.enable = true;
    uninstallUnmanaged = true;
    packages = [
      "md.obsidian.Obsidian"
      "org.chromium.Chromium"
      "org.onlyoffice.desktopeditors"
      "org.ryujinx.Ryujinx"

      # Gamescope for Steam (deadlock isn't multi-monitor aware)
      # "org.freedesktop.Platform.VulkanLayer.gamescope"
    ];

    overrides = {
      # global.Environment.GTK_THEME = "stylix";
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

      "org.ryujinx.Ryujinx".Context = {
        sockets = ["x11"];
        devices = [ "dri" "input" ];
        filesystems = [ "home/CryptVMs" ];
      };
      "org.chromium.Chromium".Context.sockets = ["x11"];
      "org.onlyoffice.desktopeditors".Context.sockets = ["x11"];
      "md.obsidian.Obsidian".Context.filesystems = [ "xdg-documents/Obsidian" ];
    };
  };

  # home.file.".var/app/org.chromium.Chromium/config/chromium-flags.conf".text = ''
    # --enable-features=UseOzonePlatform
    # --ozone-platform=wayland
  # '';
}
