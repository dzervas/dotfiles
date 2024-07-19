{ config, pkgs, ... }: {
  xdg = {
    enable = true;
    portal = {
      enable = true;
      # wlr.enable = true;
      xdgOpenUsePortal = true;
      extraPortals = with pkgs; [ xdg-desktop-portal-gtk xdg-desktop-portal-wlr ];
      config = {
        common = {
          # default = ["gtk" "wlr"];
          default = [ "wlr" ];
          "org.freedesktop.impl.portal.Screencast" = "wlr";
          "org.freedesktop.impl.portal.Screenshot" = "wlr";
        };
      };
    };
    userDirs = {
      enable = true;
      createDirectories = true;
    };

    mimeApps = {
      enable = true; # Auto-populate default apps
      defaultApplications = {
        "x-scheme-handler/http" = config.setup.browser;
        "x-scheme-handler/https" = config.setup.browser;
        "x-scheme-handler/chrome" = config.setup.browser;
        "text/html" = config.setup.browser;
        "text/xml" = config.setup.browser;
        "application/pdf" = config.setup.browser;
        "application/x-extension-htm" = config.setup.browser;
        "application/x-extension-html" = config.setup.browser;
        "application/x-extension-shtml" = config.setup.browser;
        "application/x-extension-xhtml" = config.setup.browser;
        "application/x-extension-xht" = config.setup.browser;
        "application/rdf+xml" = config.setup.browser;
        "application/rss+xml" = config.setup.browser;
        "application/xhtml+xml" = config.setup.browser;
        "application/xhtml_xml" = config.setup.browser;
        "application/xml" = config.setup.browser;
      };
    };
  };
}
