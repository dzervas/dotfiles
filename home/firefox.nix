{ hostName, ... }: {
  # Issues:
  # - Skroutz iframe is broken

  # setup.browser = "firefox";

  stylix.targets.firefox.profileNames = ["default"];
  programs.firefox = {
    enable = true;
    policies = {
      DisablePocket = true;
      DisableTelemetry = true;
      DisableDeveloperTools = false;
      DisableFeedbackCommands = true;
      DisableSetDesktopBackground = true;
      DontCheckDefaultBrowser = true;
      HardwareAcceleration = true;
      NoDefaultBookmarks = true;
      OfferToSaveLogins = false;
      PasswordManagerEnabled = false;
    };
    # Creating a new profile breaks firefox - no addons, no settings, etc.
    profiles = {
      default = {
        name = "Default";
        path = "8prfdmmp.default"; # Generated once so let's use it
        isDefault = true;
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
          "browser.tabs.inTitlebar" = 1;
          "sidebar.visibility" = "always-show";
          "sidebar.main.tools" = "aichat,bookmarks";
          "sidebar.position_start" = false; # true = left, false = right

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
          "geo.provider.use_geoclue" = false;
          # To fake location:
          "geo.provider.network.url" = ''data:application/json,{"location": {"lat": 35.309551, "lng": 25.084790}, "accuracy": 27000.0}'';
          "network.captive-portal-service.enabled" = false;
          # This results in numerous issues - iframes don't work as expected, (skroutz), weird broken sites, etc.
          "network.http.sendRefererHeader" = 2; # 0 for no referer, 1 for only clicked links, 2 for everything
          "privacy.resistFingerprinting" = false; # Resets prefers-color-scheme to light :/
          "privacy.trackingprotection.enabled" = true;
          "privacy.trackingprotection.socialtracking.enabled" = true;
          "privacy.globalprivacycontrol.enabled" = true; # Tell websites not to sell or share my data (lol)
          "privacy.globalprivacycontrol.was_ever_enabled" = true;
          "privacy.donottrackheader.enabled" = true;
          "services.sync.prefs.sync.privacy.donottrackheader.enabled" = true;
          "browser.safebrowsing.malware.enabled" = false;
          "services.sync.prefs.sync.browser.safebrowsing.malware.enabled" = false;
          "browser.safebrowsing.phishing.enabled" = false;
          "services.sync.prefs.sync.browser.safebrowsing.phishing.enabled" = false;

          # Enhanced Tracking Protection
          "privacy.annotate_channels.strict_list.enabled" = true;
          "privacy.bounceTrackingProtection.mode" = true;
          "privacy.query_stripping.enabled" = true;
          "privacy.query_stripping.enabled.pbmode" = true;

          # Sync
          "services.sync.declinedEngines" = "passwords,creditcards";
          "services.sync.engine.passwords" = false;
          "services.sync.engine.prefs" = false;

          # Make the .lan TLD whitelisted
          "browser.fixup.domainsuffixwhitelist.lan" = true;

          # ToolBar state
          "browser.uiCustomization.state" = builtins.toJSON {
            placements = {
              widget-overflow-fixed-list = [];
              unified-extensions-area = [
                "search_kagi_com-browser-action"
                "dearrow_ajay_app-browser-action"
                "plasma-browser-integration_kde_org-browser-action"
                "_ublacklist-browser-action"
                "gdpr_cavi_au_dk-browser-action"
                "https-everywhere_eff_org-browser-action"
                "sponsorblocker_ajay_app-browser-action"
              ];
              nav-bar = [
                "back-button"
                "forward-button"
                "stop-reload-button"
                "urlbar-container"
                "downloads-button"
                "ublock0_raymondhill_net-browser-action"
                "_d634138d-c276-4fc8-924b-40a0ea21d284_-browser-action"
                "fxa-toolbar-menu-button"
                "_testpilot-containers-browser-action"
                "unified-extensions-button"
              ];
              toolbar-menubar = [ "menubar-items" ];
              TabsToolbar = [
                "tabbrowser-tabs"
                "new-tab-button"
                "alltabs-button"
              ];
              PersonalToolbar = [ "personal-bookmarks" ];
            };
            seen = [
              "gdpr_cavi_au_dk-browser-action"
              "_testpilot-containers-browser-action"
              "_ublacklist-browser-action"
              "ublock0_raymondhill_net-browser-action"
              "_d634138d-c276-4fc8-924b-40a0ea21d284_-browser-action"
              "sponsorblocker_ajay_app-browser-action"
              "developer-button"
              "search_kagi_com-browser-action"
              "https-everywhere_eff_org-browser-action"
              "dearrow_ajay_app-browser-action"
              "screenshot-button"
            ];
            dirtyAreaCache = [
              "unified-extensions-area"
              "nav-bar"
              "toolbar-menubar"
              "TabsToolbar"
              "PersonalToolbar"
              "vertical-tabs"
            ];
            currentVersion = 100;
            newElementCount = 6;
          };

          # New tab page
          "browser.newtabpage.activity-stream.section.highlights.includePocket" = false;
          "services.sync.prefs.sync.browser.newtabpage.activity-stream.section.highlights.includePocket" = false;
          "services.sync.prefs.sync-seen.browser.newtabpage.activity-stream.section.highlights.includePocket" = false;
          "services.sync.prefs.sync.browser.newtabpage.activity-stream.showSponsored" = false;
          "services.sync.prefs.sync-seen.browser.newtabpage.activity-stream.showSponsored" = false;
          "services.sync.prefs.sync.browser.newtabpage.activity-stream.showSponsoredTopSites" = false;
          "services.sync.prefs.sync-seen.browser.newtabpage.activity-stream.showSponsoredTopSites" = false;
          "browser.newtabpage.activity-stream.topSitesRows" = 2;
          "browser.newtabpage.pinned" = builtins.toJSON [
            { label = "NixOS Search"; url = "https://search.nixos.org/packages?channel=unstable"; customScreenshotURL = "https://search.nixos.org/images/nix-logo.png"; }
            { label = "Home Manager"; url = "https://home-manager-options.extranix.com/?release=master"; }
            { label = "DevEnv"; url = "https://devenv.sh/"; }
            { label = "NixVim"; url = "https://nix-community.github.io/nixvim/search/"; customScreenshotURL = "https://github.com/nix-community/nixvim/raw/refs/heads/main/assets/nixvim_logo.svg"; }
            { label = "HackADay"; url = "https://hackaday.com/"; }
            { label = "HackerNews"; url = "https://news.ycombinator.com/"; }
            { label = "Lobsters"; url = "https://lobste.rs"; }
            { label = "Kagi News"; url = "https://kite.kagi.com"; customScreenshotURL = "https://kite.kagi.com/svg/kagi_news_icon.svg"; }
            { label = "HASS"; url = "https://hass.dzerv.art/"; }
            { label = "n8n"; url = "https://auto.dzerv.art/"; }
            { label = "GitHub"; url = "https://github.com/"; }
            { label = "Skroutz"; url = "https://www.skroutz.gr/"; }
          ];
        };
      };
    };
  };
}
