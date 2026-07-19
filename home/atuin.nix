{ config, lib, pkgs, ... }: let
  atuinAiConfig = pkgs.writeText "atuin-ai-config.toml" ''
    port = 11337
    endpoint = "http://host.containers.internal:1337/v1"
    default_model = "ornith"

    [request.body]
    stream_options = { include_usage = true }

    [[models]]
    alias = "ornith"
    name = "Ornith 1.0 9B"
    description = "Local Ornith via llama-swap"
    model = "ornith"
  '';

  # Copy-pasta of https://github.com/nix-community/home-manager/blob/master/modules/programs/atuin.nix#L172C7-L180
  atuinFishConfig = pkgs.runCommand "atuin-fish-config.fish"
    {
      nativeBuildInputs = [ pkgs.writableTmpDirAsHomeHook ];
    }
    ''
      ${lib.getExe config.programs.atuin.package} pty-proxy init fish > "$out"
      ${lib.getExe config.programs.atuin.package} ai init fish >> "$out"
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

      ai = {
        enabled = true;
        endpoint = "http://127.0.0.1:11337";
      };

      history_filter = [
        # Ignore space-prefixed commands
        "^\\s+"
      ];
    };
  };

  # Atuin AI's local protocol server, backed by the system llama-swap service.
  services.podman = {
    enable = true;
    containers.atuin-ai = {
      image = "ghcr.io/atuinsh/atuin-ai-server:latest";
      description = "Self-hosted Atuin AI server";
      ports = [ "127.0.0.1:11337:11337" ];
      volumes = [ "${atuinAiConfig}:/etc/atuin-ai/config.toml:ro" ];
    };
  };

  xdg.configFile."atuin-ai/config.toml".source = atuinAiConfig;

  programs.fish.interactiveShellInit = ''
    source ${atuinFishConfig}
  '';
}
