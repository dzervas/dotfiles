{
  config,
  lib,
  pkgs,
  ...
}:
let
  zetaModel = "LeaderboardModel1/zeta-2.1-autoround-W4A16";
  agentModel = "mrexodia/Ornith-1.0-35B-AEON-Ultimate-Uncensored-MTP-GGUF:Q4_K_M";

  hfCache = "/home/dzervas/CryptVMs/huggingface/";
  llamaSwapModelsDir = "${config.home.homeDirectory}/.local/share/llama-swap";

  # d run -d --name zeta -p 127.0.0.1:1337:8000 --ipc=host --gpus all -e PYTORCH_CUDA_ALLOC_CONF=expandable_segments:True -e VLLM_SERVER_DEV_MODE=1 -v ~/.cache/vllm:/root/.cache/vllm -v ~/.cache/huggingface:/root/.cache/huggingface vllm/vllm-openai:latest LeaderboardModel1/zeta-2.1-autoround-W4A16 \
  #           --served-model-name zeta-2.1 \
  #           --max-model-len 6K \
  #           --max-num-seqs 1 \
  #           --gpu-memory-utilization 0.50 \
  #           --enable-prefix-caching \
  #           --no-enable-chunked-prefill \
  #           --max-num-batched-tokens 8K \
  #           --kv-cache-dtype fp8 \
  #           --enable-sleep-mode \
  #           --speculative-config '{"method": "ngram","num_speculative_tokens": 12,"prompt_lookup_min": 2,"prompt_lookup_max": 4}'
  # d run -d --name ornith --gpus all --shm-size=8g -p 1338:8080 -v "$HOME/.cache/huggingface:/root/.cache/huggingface" ghcr.io/ggml-org/llama.cpp:server-cuda \
  # -hf mrexodia/Ornith-1.0-35B-AEON-Ultimate-Uncensored-MTP-GGUF:Q4_K_M --tools all --host 0.0.0.0 --port 8080 -c 100000 -np 1 -ngl all --cpu-moe -ncmoe 24 --spec-type draft-mtp --spec-draft-n-max 3 -fa on -ctk q4_0 -ctv q4_0 -t 16 -tb 16 -b 2048 -ub 512

  # TODO: pkgs.writers.writeYAML
  llamaSwapConfig = pkgs.writeText "llama-swap-config.yaml" ''
logLevel: debug
logToStdout: both

models:
  zeta:
    cmd: >
      sh -ec '
        curl -fsS -X POST http://zeta:8080/wake_up >/dev/null;
        exec sleep infinity
      '

    cmdStop: >
      sh -ec '
        curl -fsS -X POST "http://zeta:8080/sleep?level=1&mode=abort" >/dev/null;
        kill $${PID}
      '

  ornith:
    cmd: sh -ec 'exec sleep infinity'
    cmdStop: >
      sh -ec '
        curl -X POST --json '{"model": "${agentModel}"}' http://llama-agent:8080/models/unload
        kill $${PID}
      '

routing:
  router:
    use: group
    settings:
      groups:
        gpu:
          swap: true
          exclusive: true
          members:
            - zeta
            - ornith
  '';

  llamaAgentConfig = pkgs.writeText "llama.ini" (lib.generators.toINIWithGlobalSection {} {
    globalSection.version = 1;
    sections = {
      "*" = {
        parallel = 1;
        n-gpu-layers = "all";

        flash-attn = "on";
        cache-type-k = "q4_0";
        cache-type-v = "q4_0";

        threads = 16;
        batch-size = 2048;
        ubatch-size = 512;
      };
      ${agentModel} = {
        ctx-size = 100000;
        cpu-moe = true;
        n-cpu-moe = 24; # Lower consumes more VRAM but it's about as fast

        spec-type = "draft-mtp";
        spec-draft-n-max = 3;
      };
    };
  });

  # TODO: pkgs.writers.writeTOML
  atuinAiConfig = pkgs.writeText "atuin-ai-config.toml" ''
    port = 11337
    endpoint = "http://llama-swap:1337/v1"
    default_model = "ornith"

    [request.body]
    stream_options = { include_usage = true }

    [[models]]
    alias = "ornith"
    name = "Ornith 1.0 35B"
    description = "Local Ornith via llama-swap"
    model = "ornith"
  '';

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

  # Local AI containers share a bridge network with container-name DNS.
  services.podman = {
    enable = true;
    # enable = false;
    enableTypeChecks = true;

    networks.local-ai = {
      description = "Local AI services";
      driver = "bridge";
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
        image = "ghcr.io/mostlygeek/llama-swap:cpu";
        description = "Local LLM model swapper";
        network = [ "local-ai.network" ];
        networkAlias = [ "llama-swap" ];
        ports = [ "127.0.0.1:1337:1337" ];
        devices = [ "nvidia.com/gpu=all" ];
        exec = "-config /etc/llama-swap/config/config.yaml -listen 0.0.0.0:1337 -watch-config";
        volumes = [
          "${llamaSwapConfig}:/etc/llama-swap/config/config.yaml:ro"
          "${llamaSwapModelsDir}:/models"
        ];
        extraConfig.Container.GroupAdd = "keep-groups";
      };

      llama-agent = {
        image = "ghcr.io/ggml-org/llama.cpp:server-cuda";
        description = "LLamma for agent model";
        network = [ "local-ai.network" ];
        networkAlias = [ "llama-agent" ];
        devices = [ "nvidia.com/gpu=all" ];
        exec = "--models-preset /models.ini";
        volumes = [
          "${llamaAgentConfig}:/models.ini:ro"
          "${hfCache}:/root/.cache/huggingface"
        ];
        extraConfig.Container.GroupAdd = "keep-groups";
      };

      zeta = {
        image = "vllm/vllm-openai:latest";
        description = "LLamma for agent model";
        network = [ "local-ai.network" ];
        networkAlias = [ "zeta" ];
        devices = [ "nvidia.com/gpu=all" ];
        environment = {
          PYTORCH_CUDA_ALLOC_CONF = "expandable_segments:True";
          VLLM_SERVER_DEV_MODE = "1";
        };
        # TODO: Make this a proper config
        exec = ''${zetaModel} \
          --served-model-name zeta-2.1 \
          --max-model-len 6K \
          --max-num-seqs 1 \
          --gpu-memory-utilization 0.50 \
          --enable-prefix-caching \
          --no-enable-chunked-prefill \
          --max-num-batched-tokens 8K \
          --kv-cache-dtype fp8 \
          --enable-sleep-mode \
          --speculative-config '{"method": "ngram","num_speculative_tokens": 12,"prompt_lookup_min": 2,"prompt_lookup_max": 4}'
        '';
        volumes = [
          "/home/dzervas/CryptVMs/vllm:/root/.cache/vllm"
          "${hfCache}:/root/.cache/huggingface"
        ];
        extraConfig.Container.GroupAdd = "keep-groups";
      };
    };
  };

  home.activation.createLlamaSwapModelsDir = lib.hm.dag.entryAfter [ "writeBoundary" ] ''
    run mkdir -p ${lib.escapeShellArg llamaSwapModelsDir}
  '';

  xdg.configFile."atuin-ai/config.toml".source = atuinAiConfig;

  programs.fish.interactiveShellInit = ''
    source ${atuinFishConfig}
  '';
}
