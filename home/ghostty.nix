{ config, ... }: {
  # TODO: Slow startup
  # TODO: Handle local file urls with nvim
  setup.terminal = "ghostty";
  programs.ghostty = {
    enable = true;
    installVimSyntax = true;
    settings = {
      background-opacity = 0.85;
      cursor-style = "block";
      cursor-style-blink = false;
      font-family = config.stylix.fonts.monospace.name;
      font-size = config.stylix.fonts.sizes.terminal;
      gtk-single-instance = true;
      shell-integration-features = "no-cursor"; # Fish sets cursor as bar

      keybind = [
        "shift+enter=text:\n" # Claude Code fix
      ];
    };
  };

  home.sessionVariables.TERMINAL = "ghostty";
}
