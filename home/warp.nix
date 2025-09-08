{ config, pkgs, ... }: {
  # setup.terminal = "warp-terminal";
  home = {
    packages = [ pkgs.warp-terminal ];
    # sessionVariables.TERMINAL = "warp-terminal";
    # file."${config.xdg.configHome}/warp-terminal/user_preferences.json".text = builtins.toJSON {
    #   prefs = {
    #     HonorPS1 = "true";
    #     CursorDisplayType = "Block";
    #     ShouldAddAgentModeChip = "false";
    #     EnteredAgentModeNumTimes = "3";
    #     ReceivedReferralTheme = "Inactive";
    #     WorkflowsBoxOpen = "true";
    #     NextCommandSuggestionsUpgradeBannerNumTimesShownThisPeriod = "0";
    #     DidNonAnonymousUserLogIn = "false";
    #     WorkflowAliases = "[]";
    #     Theme = "Dracula";
    #
    #     FontName = config.stylix.fonts.monospace.name;
    #     FontSize = config.stylix.fonts.sizes.terminal;
    #     NotebookFontSize = config.stylix.fonts.sizes.desktop;
    #     LigatureRenderingEnabled = "true";
    #
    #     AgentModeOnboardingBlockShown = "true";
    #     HasAutoOpenedWelcomeFolder = "true";
    #     # WarpDriveSharingOnboardingBlockShown = "true";
    #     # AgentModeOnboardingBlockShown = "2";
    #   };
    # };
  };
}
