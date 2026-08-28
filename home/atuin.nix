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
  llamaSwapConfig = pkgs.writers.writeYAML "llama-swap-config.yaml" {
    logToStdout = "both";
    healthCheckTimeout = 300;

    models = {
      "zeta-2.1" = {
        cmd = ''vllm serve --host 127.0.0.1 --port ''${PORT} --config /vllm-zeta.yaml'';
        aliases = ["zeta"];
        capabilities = {
          "in" = ["text"];
          out = ["text"];
          context = 6144;
        };
      };
      ornith = {
        # Reproduce offmonreal's measured TurboQuant Q4 donor-MTP recipe first.
        cmd = lib.concatStringsSep " " [
          ''turboquant-server --host 127.0.0.1 --port ''${PORT}''
          "--model /root/.cache/huggingface/hub/models--offmonreal--Ornith-1.5-35B-MaxQuality-MTP-GGUF/snapshots/33b1d387e9fca2bf07e0a949d3db25f4babc389f/Ornith-1.5-35B_Q4_K_M_imatrix_MTP.gguf"
          "--jinja"
          # Remove this override to A/B against the GGUF's embedded Ornith template.
          "--chat-template-file /qwen-fixed-chat-template.jinja"
          "--reasoning-format deepseek"
          "--parallel 1"

          "--fit off"
          "--n-gpu-layers 99"
          "--n-cpu-moe 0"
          "--override-tensor"
          (lib.escapeShellArg ''blk\.(1[89]|2[0-9]|3[0-9])\.ffn_.*_exps\.weight=CPU'')
          "--no-mmap"

          "--ctx-size 131072"
          "--flash-attn on"
          # TurboQuant upgrades symmetric turbo K on this 8:1 GQA model anyway.
          "--cache-type-k q8_0"
          "--cache-type-v turbo3"
          "--batch-size 32768"
          "--ubatch-size 512"
          "--threads 16"
          "--cache-reuse 256"

          "--spec-type draft-mtp"
          "--spec-draft-n-max 2"

          "--temp 0.6"
          "--top-k 20"
          "--top-p 0.95"
          "--min-p 0"
        ];
        aliases = ["ornith"];
        capabilities = {
          "in" = ["text"];
          out = ["text"];
          context = 131072;
          thinking = true;
        };
      };

      qwen3 = {
        cmd = lib.concatStringsSep " " [
          ''ik-llama-server --host 127.0.0.1 --port ''${PORT}''
          "--model /root/.cache/huggingface/hub/models--vcruz305--Qwen3.8-27B-AEON-ULTIMATE-UNCENSORED-GGUF/snapshots/b1b47502a84d9f92226fdcf7ef14556436e889ba/Qwen3.8-27B-AEON-ULTIMATE-UNCENSORED-Q3_K_M.gguf"

          # Agent/tool parsing
          "--jinja"
          "--peg"
          "--reasoning-format deepseek"

          # Single agent sequence
          "--parallel 1"

          # GPU
          # "--n-gpu-layers 999"
          "--flash-attn on"

          "--cache-type-k q4_0"
          "--cache-type-v q4_0"

          "--fit"
          "--fit-margin 2048"

          # 16 GB 5080: leave headroom
          "--cache-type-k q4_0"
          "--cache-type-v q4_0"
          "--ctx-size 131072"

          # Avoid giant prefill buffers
          "--batch-size 256"
          "--ubatch-size 128"

          "--threads 16"

          # ik_llama optimizations
          "--run-time-repack"
          "--mlock"

          # Qwen3.8 thinking-mode sampling
          "--temp 1.0"
          "--top-k 20"
          "--top-p 0.95"
          "--min-p 0"
          "--presence-penalty 0"
          "--repeat-penalty 1.0"

          # Looping fix
          "--reasoning-budget 4096"
          ''--reasoning-budget-message " \n\n[Thinking budget exceeded. Transitioning to a best-effort final answer: ]\n\n"''

          # Draft model
          "--spec-type ngram-mod:n_max=64,n_min=2,ngram_size_n=8"
          "--spec-type mtp:n_max=3,p_min=0.0"
          "--spec-autotune"
        ];

        capabilities = {
          "in" = ["text"];
          out = ["text"];
          context = 131072;
          thinking = true;
        };
      };
    };

    store.path = "/data/llama-swap.sqlite";
    routing.router = {
      use = "group";
      settings.groups.gpu = {
        swap = true;
        exclusive = true;
        members = [
          "zeta"
          "ornith"
        ];
      };
    };
  };

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
          "${llamaSwapConfig}:/etc/llama-swap/config/config.yaml:ro"
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
