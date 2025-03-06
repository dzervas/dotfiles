_: {
  # To update shortcuts: nix-shell -p desktop-file-utils --run "update-desktop-database -v"
  services.flatpak = {
    enable = true;
    update.auto.enable = true;
    uninstallUnmanaged = true;
    packages = [
      "md.obsidian.Obsidian"
      # "org.chromium.Chromium"
      "org.onlyoffice.desktopeditors"
      "org.ryujinx.Ryujinx"
      "org.signal.Signal"
      "com.github.skylot.jadx"
      "com.slack.Slack"
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
      # "org.chromium.Chromium".Context.sockets = ["wayland"];
      "org.signal.Signal".Context.sockets = ["x11"];
      "org.onlyoffice.desktopeditors".Context.sockets = ["x11"];
      "md.obsidian.Obsidian".Context.filesystems = [ "xdg-documents/Obsidian" ];
      "com.slack.Slack".Context.sockets = ["wayland" "pulseaudio"];
    };
  };

  # TODO: Move to wayland-fixes
  # Is it taken into account?
  # Vulkan stuff from https://wiki.archlinux.org/title/Chromium#Vulkan
  # Might need manually setting wayland by `org.chromium.Chromium --ozone-platform-hint=wayland`
  # and then setting "Wayland" in chrome://flags/#ozone-platform-hint
  # home.file.".var/app/org.chromium.Chromium/config/chromium-flags.conf".text = ''
    # --enable-features=VaapiVideoDecoder,VaapiIgnoreDriverChecks,Vulkan,DefaultANGLEVulkan,VulkanFromANGLE
    # --ozone-platform=wayland
  # '';
}
