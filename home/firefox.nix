{ hostName, ... }: {
  setup.browser = "firefox";
  programs.firefox = {
    enable = true;
    policies = {
      DisablePocket = true;
      DisableTelemetry = true;
      DontCheckDefaultBrowser = true;
      HardwareAcceleration = true;
      OfferToSaveLogins = false;
      PasswordManagerEnabled = false;
    };
    profiles.default = {
      path = "8prfdmmp.default"; # Generated once so let's use it
      userChrome = ''
        /* Remove close button */
        .titlebar-buttonbox-container { display:none !important }
      '';
      settings = {
        "identity.fxaccounts.account.device.name" = hostName;
        "svg.context-properties.content.enabled" = true;

        "toolkit.legacyUserProfileCustomizations.stylesheets" = true;

        # Weird shit
        "browser.discovery.enabled" = false;
        "browser.newtabpage.activity-stream.feeds.telemetry" = false;
        "browser.shopping.experience2023.enabled" = false;
        "browser.urlbar.pocket.featureGate" = false;
        "browser.urlbar.trending.featureGate" = false;
        "extensions.getAddons.showPane" = false;
        "extensions.htmlaboutaddons.recommendations.enabled" = false;
        "extensions.pocket.enabled" = false;

        # Some defaults
        "browser.aboutConfig.showWarning" = false;
        "browser.bookmarks.restore_default_bookmarks" = false;
        "browser.compactmode.show" = true;
        "browser.ctrlTab.sortByRecentlyUsed" = true;
        "browser.newtabpage.activity-stream.showSponsored" = false;
        "browser.newtabpage.activity-stream.showSponsoredTopSites" = false;
        "browser.newtabpage.activity-stream.default.sites" = "";
        "browser.translations.neverTranslateLanguages" = "el";
        "findbar.highlightAll" = true;
        "reader.content_width" = 5;

        # Disable engagement pop-ups
        "browser.engagement.ctrlTab.has-used" = true;
        "browser.engagement.downloads-button.has-used" = true;
        "browser.engagement.fxa-toolbar-menu-button.has-used" = true;
        "browser.engagement.home-button.has-used" = true;
        "browser.engagement.library-button.has-used" = true;
        "browser.engagement.sidebar-button.has-used" = true;
        "browser.translations.panelShown" = true;
        "identity.fxaccounts.toolbar.accessed" = true;
        "media.videocontrols.picture-in-picture.video-toggle.has-used" = true;
        "trailhead.firstrun.didSeeAboutWelcome" = true;

        "widget.use-xdg-desktop-portal.file-picker" = 0;

        # ToolBar state
        "browser.uiCustomization.state" = ''
          {
            "placements": {
              "widget-overflow-fixed-list": [],
              "unified-extensions-area": [
                "plasma-browser-integration_kde_org-browser-action",
                "_ublacklist-browser-action",
                "gdpr_cavi_au_dk-browser-action"
              ],
              "nav-bar": [
                "back-button",
                "forward-button",
                "stop-reload-button",
                "urlbar-container",
                "downloads-button",
                "_d634138d-c276-4fc8-924b-40a0ea21d284_-browser-action",
                "fxa-toolbar-menu-button",
                "unified-extensions-button",
                "ublock0_raymondhill_net-browser-action",
                "sponsorblocker_ajay_app-browser-action",
                "_testpilot-containers-browser-action"
              ],
              "toolbar-menubar": [
                "menubar-items"
              ],
              "TabsToolbar": [
                "tabbrowser-tabs",
                "new-tab-button",
                "alltabs-button"
              ],
              "PersonalToolbar": [
                "personal-bookmarks"
              ]
            }
          }
        '';
      };
    };
  };
}
