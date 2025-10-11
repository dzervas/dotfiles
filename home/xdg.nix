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

    autostart = {
      enable = true;
      entries = [
        # TODO: Add auto-start entries
      ];
    };

    mimeApps = {
      enable = true; # Auto-populate default apps
      defaultApplications = let
        browser = "${config.setup.browser}.desktop";
      in {
        "text/plain" = "org.kde.kate.desktop";
        "text/x-chdr" = "org.kde.kate.desktop";
        "application/x-zerosize" = "org.kde.kate.desktop";
        "application/x-wine-extension-ini" = "org.kde.kate.desktop";

        "application/vnd.ms-excel" = "org.onlyoffice.desktopeditors.desktop";

        "image/jpeg" = "org.gnome.gThumb.desktop";
        "image/png" = "org.gnome.gThumb.desktop";

        "text/html" = browser;
        "text/xml" = browser;
        "application/pdf" = browser;
        "application/x-extension-htm" = browser;
        "application/x-extension-html" = browser;
        "application/x-extension-shtml" = browser;
        "application/x-extension-xhtml" = browser;
        "application/x-extension-xht" = browser;
        "application/x-xdg-protocol-tg" = "Telegram.desktop";
        "application/x-xdg-protocol-slack" = "Slack.desktop";
        "application/rdf+xml" = browser;
        "application/rss+xml" = browser;
        "application/xhtml+xml" = browser;
        "application/xhtml_xml" = browser;
        "application/xml" = browser;

        "model/stl" = "f3d-plugin-native.desktop";

        "x-scheme-handler/http" = browser;
        "x-scheme-handler/https" = browser;
        "x-scheme-handler/chrome" = browser;
        "x-scheme-handler/orcaslicer" = "OrcaSlicer.desktop";
        "x-scheme-handler/prusaslicer" = "OrcaSlicer.desktop";
        "x-scheme-handler/bambustudio" = "OrcaSlicer.desktop";
        "x-scheme-handler/slack" = "Slack.desktop";
        "x-scheme-handler/atuin" = "Atuin.desktop";
        "x-scheme-handler/tg" = "Telegram.desktop";
      };
    };
  };
}
