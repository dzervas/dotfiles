{ config, inputs, pkgs, ... }:
{
  setup = {
    runner = "noctalia msg panel-toggle launcher";
    locker = "noctalia msg session lock";
    lockerInstant = config.setup.locker;
  };

  programs.noctalia = {
    enable = true;
    package = inputs.noctalia.packages.${pkgs.stdenv.hostPlatform.system}.default;
  };

  xdg.configFile."noctalia/config.toml".source = config.lib.file.mkOutOfStoreSymlink "${config.home.homeDirectory}/Lab/dotfiles/home/noctalia.toml";

  programs.niri.settings.spawn-at-startup = [{ sh = "noctalia"; }];
}
