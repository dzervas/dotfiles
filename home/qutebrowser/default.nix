{ config, pkgs, ... }: let
  # Main directory for wrapped qutebrowser instances
  quteDir = "${config.xdg.dataHome}/quteWrap";

  english = builtins.fetchurl {
    url = "https://chromium.googlesource.com/chromium/deps/hunspell_dictionaries.git/+/main/en-US-10-1.bdic?format=TEXT";
    sha256 = "1bxn778sqd6q144hr4d6l18s34n1mjc6bp6dsjlp2sbhw4kh38h1";
  };
  greek = builtins.fetchurl {
    url = "https://chromium.googlesource.com/chromium/deps/hunspell_dictionaries.git/+/main/el-GR-3-0.bdic?format=TEXT";
    sha256 = "1cmv8v9kyimivhfqavlafb9131k3csv2r5s0w7v33g8qf4jva5v2";
  };

  # Function that creates a desktop and the config for the target app
  # It returns a function that can be imported (hence the { ... } arguments)
  quteDesktopWrap = {
    name, # Name of the app
    url, # URL to open
    icon, # Icon URL (for the desktop entry)
    iconSha256, # Icon SHA256 hash
    emoji, # Emoji to use in the titlebar
    categories ? [], # Categories for the desktop entry
    greasemonkey ? [], # Greasemonkey scripts to load (paths)
    scheme ? null, # Scheme to associate with the app
    customAdblock ? false # Use the custom adblock rules in adblock/${name}.txt
  }: let
    baseDir = "${quteDir}/${name}";
  in _: {
    xdg.desktopEntries.${name} = {
      inherit name categories;
      icon = builtins.fetchurl {
        url = icon;
        sha256 = iconSha256;
      };
      exec = ''${config.programs.qutebrowser.package}/bin/qutebrowser --override-restore --basedir ${baseDir} --config-py ${baseDir}/config.py --target window ":adblock-update" "${url}"'';
    };

    xdg.mimeApps.defaultApplications = if builtins.isString scheme then
      { "x-scheme-handler/${scheme}" = "${name}.desktop"; }
    else {};

    # Do a merge as `home.file` is already used above
    home.file = let
      acc = {}; # Accumulator, passed on each foldl' iteration to append to it
      adblock = if customAdblock then builtins.readFile ./adblock/${name}.txt else "";
      adblockPath = if customAdblock then "${baseDir}/${name}.adblock.txt" else "";
    in builtins.foldl' (
      prev: script: let # Call foldl', a reducer function, with the accumulator and the current element
        scriptName = baseNameOf (toString script); # Get the name of the script
      in prev // {
        "${baseDir}/config/greasemonkey/${scriptName}".source = script;
    }) acc greasemonkey // { # Return the previous accumulator + the new element
      # Append a non-generated file, the config that will be used
      "${baseDir}/config.py".text = builtins.replaceStrings ["{{url}}" "{{emoji}}" "{{adblock}}"] [url emoji adblockPath] (builtins.readFile ./config.py);
      "${baseDir}/data/qtwebengine_dictionaries/en-US-10-1.bdic".source = english;
      "${baseDir}/data/qtwebengine_dictionaries/el-GR-3-0.bdic".source = greek;
    } // (
      if customAdblock then {
        ${adblockPath}.text = adblock;
      } else {}
    );
  };

in {
  programs.qutebrowser = {
    enable = true;
    package = pkgs.qutebrowser.override { enableWideVine = true; };
    searchEngines = {
      DEFAULT = "https://www.google.com/search?hl=en&q={}";
      gh = "https://github.com/search?type=repositories&q={}";
    };
    settings = {
      spellcheck.languages = [ "en-US" "el-GR" ];
      colors.webpage.preferred_color_scheme = "dark";
    };
  };

  home.packages = with pkgs; [
    hunspell
    hunspellDicts.el-gr
    hunspellDicts.en-us
  ];

  imports = [
    (quteDesktopWrap {
      name = "Discord";
      url = "https://discord.com/app";
      # gha-updater: nix-prefetch-url https://discord.com/assets/favicon.ico
      icon = "https://discord.com/assets/favicon.ico";
      iconSha256 = "1iw1dgpr38q13difx6dc5zvzjbqfw67xrl5r1i3xsrawn6rj13hj";
      categories = [ "Network" "InstantMessaging" ];
      greasemonkey = [ ./scripts/discord.nitro.js ];
      emoji = "🎃";
      scheme = "discord";
    })
    (quteDesktopWrap {
      name = "Element";
      url = "https://app.element.io";
      # gha-updater: ICONURL="https://app.element.io/$(curl -s https://app.element.io | grep -oP 'vector-icons/apple-touch-icon-180\.[0-9a-f]+\.png')" && echo -n "$ICONURL $(nix-prefetch-url $ICONURL)"
      icon = "https://app.element.io/vector-icons/apple-touch-icon-180.5d60475.png";
      iconSha256 = "1mbc7r4x5rirp8fp7xj34vgigb21rdga6cs30rdhgdnx8pm48vsl";
      categories = [ "Network" "InstantMessaging" ];
      emoji = "♻️";
    })
    (quteDesktopWrap {
      name = "Spotify";
      url = "https://open.spotify.com/";
      # gha-updater: ICONURL="$(curl -s https://open.spotify.com/ | grep -oP 'https://open\.spotifycdn\.com/cdn/images/favicon32\.[0-9a-f]+\.png')" && echo -n "$ICONURL $(nix-prefetch-url $ICONURL)"
      icon = "https://open.spotifycdn.com/cdn/images/favicon32.b64ecc03.png";
      iconSha256 = "0mvjmi73by3ljp3fa4khvjy8savzfi6v3i6njj7nhiyc1l1wqkmn";
      categories = [ "Network" "Audio" ];
      emoji = "🎧";
      customAdblock = true;
    })
    (quteDesktopWrap {
      name = "Telegram";
      url = "https://web.telegram.org/a/";
      # gha-updater: nix-prefetch-url https://web.telegram.org/a/icon-192x192.png
      icon = "https://web.telegram.org/a/icon-192x192.png";
      iconSha256 = "1y0bdflrvliddl8s8hh0h4v2xb81s4lypdas4qjpzafpr5i7ln3f";
      categories = [ "Network" "InstantMessaging" ];
      emoji = "✈️";
      scheme = "tg";
    })
  ];
}
