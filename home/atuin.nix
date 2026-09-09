{
  config,
  lib,
  pkgs,
  hostName,
  ...
}:
let
  zetaModel = "LeaderboardModel1/zeta-2.1-autoround-W4A16";
  hfCache = "/home/dzervas/CryptVMs/huggingface/";
  llamaSwapModelsDir = "${config.home.homeDirectory}/.local/share/llama-swap";
  qwenFixedChatTemplate = ./qwen-fixed-chat-template.jinja;

  vllmZetaConfig = pkgs.writers.writeYAML "config.yaml" {
    model = zetaModel;

    served-model-name = "zeta-2.1";
    max-model-len = "6K";
    max-num-seqs = 1;
    gpu-memory-utilization = 0.50;
    enable-prefix-caching = true;
    no-enable-chunked-prefill = true;
    max-num-batched-tokens = "8K";
    kv-cache-dtype = "fp8";
    speculative-config = ''{"method": "ngram","num_speculative_tokens": 12,"prompt_lookup_min": 2,"prompt_lookup_max": 4}'';
  };

  # TODO: pkgs.writers.writeTOML
  atuinAiConfig = pkgs.writers.writeTOML "atuin-ai-config.toml" {
    port = 11337;
    endpoint = "http://llama-swap:1337/v1";
    default_model = "ornith";
    request.body.stream_options = { include_usage = true; };

    models = [{
      alias = "ornith";
      name = "Ornith 1.5 35B MaxQuality";
      description = "Local Ornith via llama-swap";
      model = "ornith";
    }];
  };

  # Copy-pasta of https://github.com/nix-community/home-manager/blob/master/modules/programs/atuin.nix#L172C7-L180
  atuinFishConfig =
    pkgs.runCommand "atuin-fish-config.fish"
      {
        nativeBuildInputs = [ pkgs.writableTmpDirAsHomeHook ];
      }
      ''
        ${lib.getExe config.programs.atuin.package} pty-proxy init fish > "$out"
        ${lib.getExe config.programs.atuin.package} ai init fish >> "$out"
      '';
in
{
  programs.atuin = {
    enable = true;
    # daemon.enable = true;
    flags = [ "--disable-up-arrow" ];

    # enableFishIntegration = false; # To use pty-proxy

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

  # Local AI containers share a bridge network with container-name DNS.
  services.podman = {
    enable = hostName == "desktop";
    enableTypeChecks = true;

    networks.local-ai = {
      description = "Local AI services";
      driver = "bridge";
    };

    builds.llama-swap-vllm = {
      file = "/home/dzervas/Lab/dotfiles/docker/Dockerfile.llama-swap-vllm";
      # tags = ["latest"];
    };

    containers = {
      atuin-ai = {
        image = "ghcr.io/atuinsh/atuin-ai-server:latest";
        description = "Self-hosted Atuin AI server";
        network = [ "local-ai.network" ];
        networkAlias = [ "atuin-ai" ];
        ports = [ "127.0.0.1:11337:11337" ];
        volumes = [ "${atuinAiConfig}:/etc/atuin-ai/config.toml:ro" ];
      };

      llama-swap = {
        image = "homemanager/llama-swap-vllm";
        description = "Local LLM model swapper";
        network = [ "local-ai.network" ];
        networkAlias = [ "llama-swap" ];
        ports = [ "1337:1337" ];
        devices = [ "nvidia.com/gpu=all" ];
        exec = "-config /etc/llama-swap/config/config.yaml -listen 0.0.0.0:1337 -watch-config";
        volumes = [
          # Mounted straight from the repository, not the store: the container
          # runs with -watch-config, so edits reload without a rebuild.
          "/home/dzervas/Lab/dotfiles/home/llama-swap.yaml:/etc/llama-swap/config/config.yaml:ro"
          "${llamaSwapModelsDir}/models:/models:ro"
          "/home/dzervas/CryptVMs/vllm:/root/.cache/vllm"
          "${hfCache}:/root/.cache/huggingface"
          "${qwenFixedChatTemplate}:/qwen-fixed-chat-template.jinja:ro"
          "${vllmZetaConfig}:/vllm-zeta.yaml:ro"
          "/home/dzervas/.local/share/llama-swap:/data"
        ];
        extraConfig.Container.GroupAdd = "keep-groups";
      };

      openwebui = {
        image = "ghcr.io/open-webui/open-webui";
        description = "Local LLM model web UI";
        network = [ "local-ai.network" ];
        networkAlias = [ "openwebui" ];
        ports = [ "1338:8080" ];
        environment.OPENAI_BASE_URL = "http://llama-swap:1337/v1";
        volumes = [
          "/home/dzervas/.local/share/openwebui/:/app/backend/data"
        ];
      };
    };
  };

  home.activation.createLlamaSwapModelsDir = lib.hm.dag.entryAfter [ "writeBoundary" ] ''
    run mkdir -p ${lib.escapeShellArg "${llamaSwapModelsDir}/models"}
  '';

  xdg.configFile."atuin-ai/config.toml".source = atuinAiConfig;

  # programs.fish.interactiveShellInit = ''
  #   source ${atuinFishConfig}
  # '';
}
