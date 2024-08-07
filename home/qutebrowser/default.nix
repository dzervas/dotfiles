{ config, pkgs, ... }: let
  # Main directory for wrapped qutebrowser instances
  quteDir = "${config.xdg.dataHome}/quteWrap";

  # Function that creates a desktop and the config for the target app
  # It returns a function that can be imported (hence the { ... } arguments)
  quteDesktopWrap = { name, url, icon, iconSha256, emoji, categories ? [], greasemonkey ? [] }: let
    baseDir = "${quteDir}/${name}";
  in { ... }: {
    xdg.desktopEntries.${name} = {
      inherit name categories;
      icon = builtins.fetchurl {
        url = icon;
        sha256 = iconSha256;
      };
      exec = "${config.programs.qutebrowser.package}/bin/qutebrowser --basedir ${baseDir} --config-py ${baseDir}/config.py --target window ${url}";
    };

    # home.file."${baseDir}/config.py".text = builtins.replaceStrings ["{{url}}"] [url] (builtins.readFile ./config.py);
    # Do a merge as `home.file` is already used above
    home.file = let
      acc = {}; # Accumulator, passed on each foldl' iteration to append to it
    in builtins.foldl' (prev: script: let # Call foldl', a reducer function, with the accumulator and the current element
      scriptName = baseNameOf (toString script); # Get the name of the script
    in prev // { "${baseDir}/config/greasemonkey/${scriptName}".source = script; }) acc greasemonkey // { # Return the previous accumulator + the new element
      # Append a non-generated file, the config that will be used
      "${baseDir}/config.py".text = builtins.replaceStrings ["{{url}}" "{{emoji}}"] [url emoji] (builtins.readFile ./config.py);
    };
  };

in {
  programs.qutebrowser = {
    enable = true;
    package = pkgs.qutebrowser.override { enableWideVine = true; };
    searchEngines = {
      DEFAULT = "https://www.google.com/search?hl=en&q={}";
      gh = "https://github.com/search?type=repositories&q={}";
    };
  };

  imports = [
    (quteDesktopWrap {
      name = "Discord";
      url = "https://discord.com/app";
      icon = "https://cdn.prod.website-files.com/6257adef93867e50d84d30e2/6266bc493fb42d4e27bb8393_847541504914fd33810e70a0ea73177e.ico";
      iconSha256 = "1y341vivhlqkdc0whnddfrllwcwdqgsmbmqa8wqdfg7r8m48iwhg";
      categories = [ "Network" "InstantMessaging" ];
      greasemonkey = [ ./scripts/discord.nitro.js ];
      emoji = "🎃";
    })
    (quteDesktopWrap {
      name = "Element";
      url = "https://app.element.io";
      icon = "https://app.element.io/vector-icons/apple-touch-icon-180.a568820.png";
      iconSha256 = "15frj7ikc7ym77nm8ah9flc5ywgb6j0mk48jlmcwzzcixpcar1yx";
      categories = [ "Network" "InstantMessaging" ];
      emoji = "♻️";
    })
    (quteDesktopWrap {
      name = "Spotify";
      url = "https://open.spotify.com/";
      icon = "https://open.spotifycdn.com/cdn/images/favicon32.b64ecc03.png";
      iconSha256 = "0mvjmi73by3ljp3fa4khvjy8savzfi6v3i6njj7nhiyc1l1wqkmn";
      categories = [ "Network" "Audio" ];
      emoji = "🎧";
    })
    (quteDesktopWrap {
      name = "Telegram";
      url = "https://web.telegram.org/a/";
      icon = "https://web.telegram.org/a/icon-192x192.png";
      iconSha256 = "1y0bdflrvliddl8s8hh0h4v2xb81s4lypdas4qjpzafpr5i7ln3f";
      categories = [ "Network" "InstantMessaging" ];
      emoji = "✈️";
    })
  ];
}
