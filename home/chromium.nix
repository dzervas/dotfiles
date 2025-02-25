{ pkgs, ... }: {
  # Issues:
  # - Can't install extensions defined below - see https://github.com/nix-community/home-manager/issues/2216
  # - Can't defined chrome://flags
  # - Can't change settings
  # - Can't define custom search engine (google)

  # chrome://ungoogled-first-run/
  programs.chromium = {
    enable = true;
    package = pkgs.ungoogled-chromium;

    extensions = [
      { id = "aeblfdkhhhdcdjpifhhbdiojplfjncoa"; } # 1Password

      { id = "cjpalhdlnbpafiamejdnhcphjbkeiagm"; } # uBlock Origin
      { id = "mnjggcdmjocbbbhaepdhchncahnbgone"; } # SponsorBlock
      { id = "pncfbmialoiaghdehhbnbhkkgmjanfhe"; } # uBlacklist
      { id = "mdjildafknihdffpkfmmpnpoiajfjnjd"; } # Consent-O-Matic
      { id = "enamippconapkdmgfgjchkhakpfinmaj"; } # DeArrow

      { id = "ocllfmhjhfmogablefmibmjcodggknml"; } # Recent Tabs (Ctrl-Tab)
    ];

    # https://github.com/ungoogled-software/ungoogled-chromium/blob/master/docs/flags.md
    commandLineArgs = [
      # Behavior
      "--disable-default-browser-promo"
      "--enable-logging=stderr"
      "--restore-last-session"
      "--extension-mime-request-handling=always-prompt-for-install"
      "--force-dark-mode"
      "--keep-old-history"

      # Wayland shit
      # TODO: Move to wayland-fixes
      "--enable-features=VaapiVideoDecoder,VaapiIgnoreDriverChecks,Vulkan,DefaultANGLEVulkan,VulkanFromANGLE,ReducedSystemInfo"
      "--ozone-platform=wayland"
    ];
  };
}
