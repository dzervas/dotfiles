{ ... }: {
  # To update shortcuts: nix-shell -p desktop-file-utils --run "update-desktop-database -v"
  services.flatpak = {
    enable = true;
    update.auto.enable = true;
    uninstallUnmanaged = true;
    packages = [
      "com.spotify.Client"
      # "com.slack.Slack"
      "com.discordapp.Discord"
      "com.prusa3d.PrusaSlicer"
      "org.chromium.Chromium"
      # "com.valvesoftware.Steam"
      "md.obsidian.Obsidian"
      "org.onlyoffice.desktopeditors"
    ];

    overrides = {
      global.Environment.GTK_THEME = "Adwaita:dark";
      global.Context.filesystems = ["xdg-config/gtk-3.0"];
      "com.prusa3d.PrusaSlicer".Context.sockets = [ "x11" "fallback-x11" ];
    };
  };
}
