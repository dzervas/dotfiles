{ pkgs, ... }: {
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

    commandLineArgs = [
      "--disable-default-browser-promo"
      "--enable-logging=stderr"
      "--enable-features=VaapiVideoDecoder,VaapiIgnoreDriverChecks,Vulkan,DefaultANGLEVulkan,VulkanFromANGLE"
      "--restore-last-session"
      "--ozone-platform=wayland"
    ];
  };
}
