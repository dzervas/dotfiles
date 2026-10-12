{ config, lib, inputs, pkgs, ... }:
{
  # v5's module disables the old filename; our Home Manager uses a directory.
  disabledModules = [ "programs/noctalia" ];

  setup = {
    runner = "noctalia msg panel-toggle launcher";
    locker = "noctalia msg session lock";
    lockerInstant = config.setup.locker;
  };

  home.packages = with pkgs; [
    ddcutil # v5 invokes this directly for external-display brightness
  ];

  programs.noctalia = {
    enable = true;
    package = inputs.noctalia.packages.${pkgs.stdenv.hostPlatform.system}.default;
  };

  xdg.configFile = {
    "noctalia/config.toml".source = lib.mkForce (config.lib.file.mkOutOfStoreSymlink "${config.home.homeDirectory}/Lab/dotfiles/home/noctalia.toml");
    # The editable config replaces Stylix's generated config.toml. Preserve its
    # per-host wallpaper in a separate TOML file, which Noctalia also loads.
    # GUI wallpaper overrides in ~/.local/state/noctalia/settings.toml win;
    # clear wallpaper.default/last/monitor there to use the host selection.
    "noctalia/host.toml".source = (pkgs.formats.toml { }).generate "noctalia-host.toml" {
      inherit (config.programs.noctalia.settings) wallpaper;
    };
  };

  programs.niri.settings.spawn-at-startup = lib.mkIf (config.setup.windowManager == "niri") [{ sh = "noctalia"; }];
}
