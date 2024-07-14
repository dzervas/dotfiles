{ ... }: {
	programs.firefox = {
		enable = true;
		policies = {
			DisablePocket = true;
			# DisableTelemetry = true;
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
				"browser.compactmode.show" = true;
				"browser.newtabpage.activity-stream.showSponsored" = false;
				"browser.newtabpage.activity-stream.showSponsoredTopSites" = false;
				"browser.newtabpage.activity-stream.default.sites" = "";

				"widget.use-xdg-desktop-portal.file-picker" = 0;
			};
		};
	};

	xdg.mimeApps.defaultApplications = {
		"x-scheme-handler/http" = "firefox.desktop";
		"x-scheme-handler/https" = "firefox.desktop";
		"x-scheme-handler/chrome" = "firefox.desktop";
		"text/html" = "firefox.desktop";
		"text/xml" = "firefox.desktop";
		"application/pdf" = "firefox.desktop";
		"application/x-extension-htm" = "firefox.desktop";
		"application/x-extension-html" = "firefox.desktop";
		"application/x-extension-shtml" = "firefox.desktop";
		"application/x-extension-xhtml" = "firefox.desktop";
		"application/x-extension-xht" = "firefox.desktop";
		"application/rdf+xml" = "firefox.desktop";
		"application/rss+xml" = "firefox.desktop";
		"application/xhtml+xml" = "firefox.desktop";
		"application/xhtml_xml" = "firefox.desktop";
		"application/xml" = "firefox.desktop";
	};
		 }
