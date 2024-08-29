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
        "browser.quitShortcut.disabled" = true;
        "browser.translations.neverTranslateLanguages" = "el";
        "findbar.highlightAll" = true;
        "layout.css.prefers-color-scheme.content-override" = 0; # force dark
        "reader.content_width" = 5;
        "reader.font_size" = 5;

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

        # Privacy
        "geo.enabled" = false;
        "network.captive-portal-service.enabled" = false;
        "network.http.sendRefererHeader" = 1; # 0 for no referer, 1 for only clicked links, 2 for everything
        "privacy.resistFingerprinting" = false; # Resets prefers-color-scheme to light :/
        "privacy.trackingprotection.enabled" = true;
        "privacy.donottrackheader.enabled" = true;
        "services.sync.prefs.sync.privacy.donottrackheader.enabled" = true;
        "browser.safebrowsing.malware.enabled" = false;
        "services.sync.prefs.sync.browser.safebrowsing.malware.enabled" = false;
        "browser.safebrowsing.phishing.enabled" = false;
        "services.sync.prefs.sync.browser.safebrowsing.phishing.enabled" = false;

        # Make the .lan TLD whitelisted
        "browser.fixup.domainsuffixwhitelist.lan" = true;

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
                "_testpilot-containers-browser-action",
                "ublock0_raymondhill_net-browser-action",
                "sponsorblocker_ajay_app-browser-action",
                "unified-extensions-button"
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
            },
            "seen": [
              "gdpr_cavi_au_dk-browser-action",
              "_testpilot-containers-browser-action",
              "_ublacklist-browser-action",
              "ublock0_raymondhill_net-browser-action",
              "_d634138d-c276-4fc8-924b-40a0ea21d284_-browser-action",
              "sponsorblocker_ajay_app-browser-action",
              "developer-button"
            ],
            "dirtyAreaCache": [
              "unified-extensions-area",
              "nav-bar",
              "toolbar-menubar",
              "TabsToolbar",
              "PersonalToolbar"
            ],
            "currentVersion": 100,
            "newElementCount": 5
          }
        '';

        # Net tab page
        "browser.newtabpage.activity-stream.section.highlights.includePocket" = false;
        "services.sync.prefs.sync.browser.newtabpage.activity-stream.section.highlights.includePocket" = false;
        "services.sync.prefs.sync-seen.browser.newtabpage.activity-stream.section.highlights.includePocket" = false;
        "services.sync.prefs.sync.browser.newtabpage.activity-stream.showSponsored" = false;
        "services.sync.prefs.sync-seen.browser.newtabpage.activity-stream.showSponsored" = false;
        "services.sync.prefs.sync.browser.newtabpage.activity-stream.showSponsoredTopSites" = false;
        "services.sync.prefs.sync-seen.browser.newtabpage.activity-stream.showSponsoredTopSites" = false;
        "browser.newtabpage.pinned" = ''
          [
            {
              "url": "https://hass.dzerv.art/",
              "label": "HASS"
            },
            {
              "url": "https://search.nixos.org/packages?channel=unstable",
              "label": "NixOS Search",
              "customScreenshotURL": "https://search.nixos.org/images/nix-logo.png"
            },
            {
              "url": "https://home-manager-options.extranix.com/?query=&release=master",
              "label": "Home Manager Options"
            },
            {
              "url": "https://hackaday.com/",
              "label": "HackADay"
            },
            {
              "url": "https://news.ycombinator.com/",
              "label": "HackerNews"
            },
            {
              "url": "https://lobste.rs",
              "label": "Lobsters"
            },
            {
              "url": "https://github.com/",
              "label": "GitHub"
            },
            {
              "url": "https://www.skroutz.gr/",
              "label": "Skroutz"
            }
          ]
        '';
      };
    };
  };
}
