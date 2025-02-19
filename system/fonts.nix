{ pkgs, ... }: {
  fonts.packages = with pkgs; [
    iosevka-bin
    nerd-fonts.iosevka
  ];

  services.kmscon.fonts = [{
    name = "Iosevka Nerd Font";
    package = pkgs.nerd-fonts.iosevka;
  }];
}
