{ ... }: {
  programs.qutebrowser = {
    enable = true;
    quickmarks = {
      discord = "https://discord.com/channels/@me";
      spotify = "https://open.spotify.com/";
    };
    searchEngines = {
      DEFAULT = "https://www.google.com/search?hl=en&q={}";
      gh = "https://github.com/search?type=repositories&q={}";
    };
  };
}
