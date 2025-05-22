{ lib, ... }: {
  setup.terminal = "alacritty";
  programs.alacritty = {
    enable = true;
    settings = {
      window = {
        decorations = "None";
        opacity = lib.mkForce 0.9;
        blur = true;
      };
    };
  };

  home.sessionVariables.TERMINAL = "alacritty";
}
