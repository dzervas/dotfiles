{ config, ... }: {
  setup.terminal = "ghostty";
  programs.ghostty = {
    enable = true;
    installVimSyntax = true;
    settings = {
      shell-integration-features = "no-cursor"; # Fish sets cursor as bar
      cursor-style = "block";
      cursor-style-blink = false;
      background-opacity = 0.85;
      font-family = config.stylix.fonts.monospace.name;
      font-size = config.stylix.fonts.sizes.terminal;
    };
  };

  home.sessionVariables.TERMINAL = "ghostty";
}
