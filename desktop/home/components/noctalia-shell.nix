{ config, lib, inputs, pkgs, ... }: {
  setup = {
    runner = "noctalia-shell ipc call launcher toggle";
    locker = "noctalia-shell ipc call lockScreen lock";
    lockerInstant = config.setup.locker;
  };

  programs.noctalia-shell = {
    enable = true;
    package = inputs.noctalia.packages.${pkgs.stdenv.hostPlatform.system}.default.override { calendarSupport = true; };
    settings = {};
    plugins = {
      version = 2;
      sources = [{ enabled = true; name = "Noctila Plugins"; url = "https://github.com/noctalia-dev/noctalia-plugins"; }];
      states = builtins.mapAttrs (_name: url: { enabled = true; sourceUrl = url; } ) {
        kaomoji-provider = "https://github.com/noctalia-dev/noctalia-plugins";
        polkit-agent = "https://github.com/noctalia-dev/noctalia-plugins";
        pomodoro = "https://github.com/noctalia-dev/noctalia-plugins";
        privacy-indicator = "https://github.com/noctalia-dev/noctalia-plugins";
        tailscale = "https://github.com/noctalia-dev/noctalia-plugins";
        zed-provider = "https://github.com/noctalia-dev/noctalia-plugins";
      };
    };
  };

  xdg.configFile."noctalia/settings.json".source = lib.mkForce (config.lib.file.mkOutOfStoreSymlink "${config.home.homeDirectory}/Lab/dotfiles/home/noctalia.json");

  programs.niri.settings.spawn-at-startup = [{ argv = ["noctalia-shell"]; }];
}
