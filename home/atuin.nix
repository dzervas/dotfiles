{ config, lib, pkgs, hostName, ... }: let
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
    endpoint = "http://strata:8080/v1";
    api_key.cmd = {
      run = "bash";
      args = [
        "-c"
        "grep -Eo 'sk-strata-\\w+' /strata_config.json"
      ];
    };
    default_model = "qwen";
    request.body.stream_options.include_usage = true;

    models = [
      {
        name = "Qwen3.8 Flash Next";
        description = "Local Qwen Flash Next through strata";
        model = "qwen";
        alias = "qwen";
      }
    ];
  };
in {
  programs.atuin = {
    enable = true;
    daemon.enable = true;
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
        capture_sessions = true;
        sessions = {
          filter_mode = "directory";
          # resume.pi = "pis --session {id}";
        };
      };

      history_filter = [
        # Ignore space-prefixed commands
        "^\\s+"
      ];
    };
  };

  # Memory runs as its own atuin account. The agent's sandbox is pinned to this profile, so a
  # sandboxed session can read and write notes without reaching the shell-history store, its key,
  # or the main account.
  xdg.configFile."atuin-agent/config.toml".text = ''
    data_dir = "${config.home.homeDirectory}/.local/share/atuin-agent"
    sync_address = "https://sh.vpn.dzerv.art"
    sync_frequency = "5m"

    [sync]
    records = true
  '';

  # Local AI containers share a bridge network with container-name DNS.
  services.podman = {
    enable = hostName == "desktop";
    enableTypeChecks = true;

    networks.local-ai = {
      description = "Local AI services";
      driver = "bridge";
    };

    # builds.llama-swap-vllm = {
    #   file = "/home/dzervas/Lab/dotfiles/docker/Dockerfile.llama-swap-vllm";
    #   tags = ["latest"];
    # };

    containers = {
      atuin-ai = {
        image = "ghcr.io/atuinsh/atuin-ai-server:latest";
        description = "Self-hosted Atuin AI server";
        network = [ "local-ai.network" ];
        networkAlias = [ "atuin-ai" ];
        ports = [ "11337:8080" ];
        volumes = [
          "${atuinAiConfig}:/etc/atuin-ai/config.toml:ro"
          "/home/dzervas/CryptVMs/strata/config/strata-iq2_xs.json:/strata_config.json:ro"
        ];
      };

      strata = {
        image = "homemanager/strata:local";
        description = "Qwen 3.8 Flash Next engine";
        autoStart = false; # Start manually: systemctl --user start podman-strata
        network = [ "local-ai.network" ];
        networkAlias = [ "strata" ];
        ports = [ "1337:8080" ];
        devices = [ "nvidia.com/gpu=all" ];
        volumes = [ "/home/dzervas/CryptVMs/strata:/data" ];
        extraConfig.Container.GroupAdd = "keep-groups";

        environment = {
          CONTEXT = "262144";
          MODEL = "IQ2_XS";
          FAMILY = "qwen";
          STRATA_NO_ARENA_THP = "1"; # Speeds up load time without huge pages
        };
      };

      # llama-swap = {
      #   image = "homemanager/llama-swap-vllm";
      #   description = "Local LLM model swapper";
      #   network = [ "local-ai.network" ];
      #   networkAlias = [ "llama-swap" ];
      #   ports = [ "1337:1337" ];
      #   devices = [ "nvidia.com/gpu=all" ];
      #   exec = "-config /etc/llama-swap/config/config.yaml -listen 0.0.0.0:1337 -watch-config";
      #   volumes = [
      #     # Mounted straight from the repository, not the store: the container
      #     # runs with -watch-config, so edits reload without a rebuild.
      #     "/home/dzervas/Lab/dotfiles/home/llama-swap.yaml:/etc/llama-swap/config/config.yaml:ro"
      #     "${llamaSwapModelsDir}/models:/models:ro"
      #     "/home/dzervas/CryptVMs/vllm:/root/.cache/vllm"
      #     "${hfCache}:/root/.cache/huggingface"
      #     "${qwenFixedChatTemplate}:/qwen-fixed-chat-template.jinja:ro"
      #     "${vllmZetaConfig}:/vllm-zeta.yaml:ro"
      #     "/home/dzervas/.local/share/llama-swap:/data"
      #   ];
      #   extraConfig.Container.GroupAdd = "keep-groups";
      # };
      #
      # openwebui = {
      #   image = "ghcr.io/open-webui/open-webui";
      #   description = "Local LLM model web UI";
      #   network = [ "local-ai.network" ];
      #   networkAlias = [ "openwebui" ];
      #   ports = [ "1338:8080" ];
      #   environment.OPENAI_BASE_URL = "http://llama-swap:1337/v1";
      #   volumes = [
      #     "/home/dzervas/.local/share/openwebui/:/app/backend/data"
      #   ];
      # };
    };
  };

  home.activation.createLlamaSwapModelsDir = lib.hm.dag.entryAfter [ "writeBoundary" ] ''
    run mkdir -p ${lib.escapeShellArg "${llamaSwapModelsDir}/models"}
  '';

  xdg.configFile."atuin-ai/config.toml".source = atuinAiConfig;
}
