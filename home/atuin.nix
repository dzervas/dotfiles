{
  config,
  lib,
  pkgs,
  ...
}:
let
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
  # d run --d --name ornith --gpus all --shm-size=8g -p 1338:8080 -v "$HOME/.cache/huggingface:/root/.cache/huggingface" ghcr.io/ggml-org/llama.cpp:server-cuda \
  # --hf-repo s-batman/Ornith-1.0-35B-NVFP4-MTP-GGUF --hf-file ornith-1.0-35b-MXFP4_MOE-MTP.gguf --tools all --host 0.0.0.0 --port 8080 -c 100000 -np 1 -ngl all --cpu-moe -ncmoe 24 --spec-type draft-mtp --spec-draft-n-max 3 -fa on -ctk q4_0 -ctv q4_0 -t 16 -tb 16 -b 2048 -ub 512

  llamaSwapConfig = pkgs.writeText "llama-swap-config.yaml" ''
    healthCheckTimeout: 600
    logLevel: debug
    logToStdout: both

    models:
      zeta:
        cmd: >-
          llama-server --port ''${PORT}
          -hf adilkairolla/zeta-2.1-GGUF --hf-file zeta-2.1-Q4_K_M.gguf
          -ngl 999 -sm none -mg 0 -fit on -fitt 1024 -fa on -ctk q8_0 -ctv q8_0 --kv-offload
          -t 16 -tb 16 -np 1 -cb --cache-prompt --cache-reuse 256
          --metrics --slots -to 30 --no-webui
          -b 2048 -ub 2048 -c 8192 -n 2048
          --temp 0.0 --top-k 0 --top-p 1.0 --min-p 0.0
          -rea off --reasoning-format none

      cmd-gate:
        cmd: >-
          llama-server --port ''${PORT}
          -hf Qwen/Qwen3-4B-GGUF --hf-file Qwen3-4B-Q4_K_M.gguf
          -ngl 999 -sm none -mg 0 -fit on -fitt 1024 -fa on -ctk q8_0 -ctv q8_0 --kv-offload
          -t 16 -tb 16 -np 1 -cb --cache-prompt --cache-reuse 256
          --metrics --slots -to 30 --no-webui
          -s 42 --temp 0.1 --top-k 20 --top-p 0.8 --min-p 0.0
          --repeat-penalty 1.0 --presence-penalty 0.0 --frequency-penalty 0.0
          -b 1024 -ub 512 -c 8192 -n 192
          -rea off --reasoning-format none

      ornith:
        cmd: >-
          llama-server --port ''${PORT}
          -hf deepreinforce-ai/Ornith-1.0-9B-GGUF --hf-file ornith-1.0-9b-Q4_K_M.gguf
          -ngl 999 -sm none -mg 0 -fit on -fitt 1024 -fa on -ctk q8_0 -ctv q8_0 --kv-offload
          -t 16 -tb 16 -np 1 -cb --cache-prompt --cache-reuse 256
          --metrics --slots -to 30 --no-webui
          -s 42 --temp 0.1 --top-k 20 --top-p 0.8 --min-p 0.0
          --repeat-penalty 1.0 --presence-penalty 0.0 --frequency-penalty 0.0
          -b 1024 -ub 512 -c 262144 -n -1
          -rea on --reasoning-budget -1 --reasoning-format deepseek --reasoning-preserve
  '';

  atuinAiConfig = pkgs.writeText "atuin-ai-config.toml" ''
    port = 11337
    endpoint = "http://llama-swap:1337/v1"
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
    # enable = true;
    enable = false;
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
        image = "ghcr.io/mostlygeek/llama-swap:unified-cuda";
        description = "Vulkan llama.cpp model server and swapper";
        network = [ "local-ai.network" ];
        networkAlias = [ "llama-swap" ];
        ports = [ "127.0.0.1:1337:1337" ];
        devices = [ "nvidia.com/gpu=all" ];
        environment = {
          HOME = "/models";
          LLAMA_CACHE = "/models";
          XDG_CACHE_HOME = "/models/.cache";
        };
        exec = "-config /etc/llama-swap/config/config.yaml -listen 0.0.0.0:1337 -watch-config";
        volumes = [
          "${llamaSwapConfig}:/etc/llama-swap/config/config.yaml:ro"
          "${llamaSwapModelsDir}:/models"
        ];
        extraConfig.Container.GroupAdd = "keep-groups";
        # extraPodmanArgs = [ "--runtime=nvidia" ];
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
