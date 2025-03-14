{ lib, ... }: {
  setup.terminal = "alacritty";
  programs.alacritty = {
    enable = true;
    settings = {
      font.size = lib.mkForce 14;
      window = {
        decorations = "None";
        opacity = lib.mkForce 0.9;
        blur = true;
      };
    };
  };

  home.sessionVariables.TERMINAL = "alacritty";
}
