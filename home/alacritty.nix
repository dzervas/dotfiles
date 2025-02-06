{ lib, ... }: {
  setup.terminal = "alacritty";
  programs.alacritty = {
    enable = true;
    settings = {
      font.size = 12;
      window = {
        decorations = "None";
        opacity = lib.mkForce 0.9;
        blur = true;
      };
    };
  };

  home.sessionVariables.TERMINAL = "alacritty";
}
