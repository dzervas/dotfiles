{ ... }: {
  setup.terminal = "alacritty";
  programs.alacritty = {
    enable = true;
    settings.font.size = 12;
  };

  home.sessionVariables.TERMINAL = "alacritty";
}
