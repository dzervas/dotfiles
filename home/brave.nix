{ pkgs, ... }: {
  # Issues:
  # - Can't install extensions defined below - see https://github.com/nix-community/home-manager/issues/2216
  # - Can't define chrome://flags
  # - Can't change settings
  # - Can't define custom search engine (kagi)

  # TODO: Make a new tab page with many things
  programs.chromium = {
    enable = true;
    package = pkgs.brave;

    extensions = [
      { id = "aeblfdkhhhdcdjpifhhbdiojplfjncoa"; } # 1Password

      { id = "cjpalhdlnbpafiamejdnhcphjbkeiagm"; } # uBlock Origin
      { id = "mnjggcdmjocbbbhaepdhchncahnbgone"; } # SponsorBlock
      { id = "enamippconapkdmgfgjchkhakpfinmaj"; } # DeArrow
      { id = "cdglnehniifkbagbbombnjghhcihifij"; } # Kagi
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

      # Most recent tab switcher
      "--enable-features=CtrlTabMRU"
    ];
  };
}
