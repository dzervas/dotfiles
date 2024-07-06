{ pkgs, ... }: {
  xdg = {
    enable = true;
    mimeApps.enable = true; # Auto-populate default apps
    portal.enable = true;
    portal.extraPortals = [ pkgs.xdg-desktop-portal-wlr ];
    portal.config = {
      common.default = "wlr";
      pantheon = {
        default = [ "pantheon" "gtk" ];
        "org.freedesktop.impl.portal.Secret" = [ "gnome-keyring" ];
      };
    };
  };

  services.gnome-keyring = {
    enable = true;
    components = [ "secrets" ];
  };
}
