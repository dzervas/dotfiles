{ config, lib, pkgs, ... }: let
  # Copy-pasta of https://github.com/nix-community/home-manager/blob/master/modules/programs/atuin.nix#L172C7-L180
  atuinFishConfig = pkgs.runCommand "atuin-fish-config.fish"
    {
      nativeBuildInputs = [ pkgs.writableTmpDirAsHomeHook ];
    }
    ''
      ${lib.getExe config.programs.atuin.package} pty-proxy init fish > "$out"
    '';
in {
  programs.atuin = {
    enable = true;
    daemon.enable = true;
    flags = [ "--disable-up-arrow" ];

    enableFishIntegration = false; # To use pty-proxy

    settings = {
      enter_accept = false;
      sync_address = "https://sh.vpn.dzerv.art";
      sync_frequency = "5m";
      sync.records = true;

      history_filter = [
        # Ignore space-prefixed commands
        "^\s+"
      ];
    };
  };

  programs.fish.interactiveShellInit = ''
    source ${atuinFishConfig}
  '';

}
