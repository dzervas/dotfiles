{
  config,
  lib,
  ...
}: {
  programs.home-manager.enable = true;
  home.username = "dzervas";
  home.homeDirectory = "/home/dzervas";
  home.stateVersion = "23.05";
}
