{ config, ... }: {
  xdg = {
    enable = true;
    portal = {
      # wlr.enable = true;
      xdgOpenUsePortal = true;
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
      defaultApplications = let
        browser = "${config.setup.browser}.desktop";
      in {
        "text/plain" = "org.kde.kate.desktop";
        "application/x-zerosize" = "org.kde.kate.desktop";

        "image/jpeg" = "org.gnome.gThumb.desktop";
        "image/png" = "org.gnome.gThumb.desktop";

        "x-scheme-handler/http" = browser;
        "x-scheme-handler/https" = browser;
        "x-scheme-handler/chrome" = browser;
        "text/html" = browser;
        "text/xml" = browser;
        "application/pdf" = browser;
        "application/x-extension-htm" = browser;
        "application/x-extension-html" = browser;
        "application/x-extension-shtml" = browser;
        "application/x-extension-xhtml" = browser;
        "application/x-extension-xht" = browser;
        "application/rdf+xml" = browser;
        "application/rss+xml" = browser;
        "application/xhtml+xml" = browser;
        "application/xhtml_xml" = browser;
        "application/xml" = browser;

        "model/stl" = "f3d-plugin-native.desktop";

        "x-scheme-handler/orcaslicer" = "OrcaSlicer.desktop";
        "x-scheme-handler/prusaslicer" = "OrcaSlicer.desktop";
        "x-scheme-handler/bambustudio" = "OrcaSlicer.desktop";
        "x-scheme-handler/slack" = "Slack.desktop";
      };
    };
  };
}
