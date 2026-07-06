{ pkgs, ... }:
{
  environment.systemPackages = with pkgs; [
    bat
    binutils
    btop
    colordiff
    cyme # Better lsusb!
    difftastic
    dig
    dmidecode
    docker-compose
    fd
    file
    fzf
    git
    inetutils
    ijq
    jq
    killall
    libnotify # For notify-send
    lsd
    ngrok
    nh
    p7zip
    pciutils
    podman-compose
    readline
    ripgrep
    sd
    socat
    statix # Lint nix files
    tree
    unzip
    usbutils
    wget

    nix-serve-ng
    rust-script
  ];

  # Set fish as the default shell
  programs.fish.enable = true;

  virtualisation = {
    containers = {
      enable = true;
      registries.search = [ "docker.io" ];
    };
    # Related pod exit session crash:
    # https://groups.google.com/g/linux.debian.bugs.dist/c/tt4F3dLan1E
    podman = {
      enable = true;
      autoPrune.enable = true;

      # Allow podman-compose containers to talk to each other
      defaultNetwork.settings.dns_enabled = true;

      dockerCompat = true;
      # dockerSocket.enable = true;
    };
  };

  security = {
    pam.services.kwallet = {
      name = "kwallet";
      enableKwallet = true;
    };
  };

  environment.variables.PODMAN_COMPOSE_WARNING_LOGS = "false";
  environment.shellAliases = {
    # Quick aliases for common commands
    "1ping" = "ping 1.1.1.1";
    c = "cargo";
    cdt = "cd $(mktemp -d)";
    d = "docker";
    dc = "docker compose";
    e = "$EDITOR";
    g = "git";
    h = "helm";
    ipy = "ipython";
    ipa = "ip -c -br a";
    jc = "curl -H \"Content-Type: application/json\" -H \"Accept: application/json\"";
    k = "kubectl";
    kn = "kubens";
    kc = "kubectx";
    l = "locate -i";
    lp = "locate -i -A \"$(pwd)\"";
    n = "echo -e \"\a\" && notify-send -a \"Terminal\" Notification!";
    p = "podman";
    pc = "podman compose";
    py = "python";
    sv = "sudoedit";
    tf = "terraform";
    v = "vim";

    # Nicer output
    man = "LC_ALL=C LANG=C command man";
    pgrep = "command pgrep -af";
    pkill = "pkill -ef";
    pwdname = "basename $(pwd)";
    ssh = "TERM=xterm-256color command ssh";
    now = "date +\"%Y.%m.%d-%H.%M.%S\"";
    # By https://unix.stackexchange.com/questions/25327/watch-command-alias-expansion
    watch = "command watch -c ";

    # Useful aliases
    docker_prune = "docker system df && docker image prune -a --filter 'until=168h' -f && docker container prune -f && docker builder prune -f && docker volume prune -f && docker system df";
    open = "xdg-open";
    passgen = "tr -dc A-Za-z0-9 </dev/urandom | head -c ";
    reboot = "read -P 'Are you sure?' && systemctl reboot";
    weather = "curl wttr.in";
    webserver = "python3 -m http.server";

    # Hipster tools
    htop = "btop";
    cat = "bat -p --style=header-filename,header-filesize,snip --paging=never";
    diff = "colordiff -ub";
    grep = "rg";
    less = "bat -p --color=always";
    ll = "lsd -Fal";
    ls = "lsd -F";
    lsusb = "cyme";
    find = "fd";
  };

  # TODO: Do we want to allow user-based keeb config?
  # Non-root access to the qmk
  hardware.keyboard.qmk.enable = true;

  services = {
    locate = {
      enable = true;
      package = pkgs.plocate;
    };

    udev.extraRules = ''
      # Add support for the thermal printer
      SUBSYSTEM=="usb", ATTRS{idVendor}=="4b43", ATTRS{idProduct}=="3538", MODE="0660", GROUP="dialout"
    '';
    llama-swap = let
      llama-server = "${pkgs.llama-cpp-vulkan}/bin/llama-server";

      # Shared GPU/placement flags (were the llama-cpp "*" preset defaults).
      gpu = "-ngl 999 -sm none -mg 0 -fit on -fitt 1024 -fa on -ctk q8_0 -ctv q8_0 --kv-offload";
      # Shared server/batching flags.
      perf = "-t 16 -tb 16 -np 1 -cb --cache-prompt --cache-reuse 256";
      # Common server behaviour (metrics/slots/timeout, no web UI).
      srv = "--metrics --slots -to 30 --no-webui";

      # Classifier sampling. Scoped to the gate/reasoning models only so it no
      # longer leaks into zeta - edit prediction must stay greedy.
      gateSampling = "-s 42 --temp 0.1 --top-k 20 --top-p 0.8 --min-p 0.0 --repeat-penalty 1.0 --presence-penalty 0.0 --frequency-penalty 0.0";
    in
      {
      enable = true;
      port = 1337;

      settings = {
      # First-request cold start may download the GGUF from Hugging Face.
      healthCheckTimeout = 600;

      # TEMP diagnostics: surface the upstream llama-server output (download
      # progress + crash errors) in the journal. Revert to defaults once happy.
      logLevel = "debug";
      logToStdout = "both";

        models = {
          # Zeta 2.1 edit prediction (SeedCoder-8B). Greedy, native 32k context.
          # Max output tokens needs to be 4x the zed config (512)
          zeta.cmd = ''
            ${llama-server} --port ''${PORT}
            -hf adilkairolla/zeta-2.1-GGUF --hf-file zeta-2.1-Q4_K_M.gguf
            ${gpu} ${perf} ${srv}
            -b 2048 -ub 2048
            -c 8192 -n 2048
            --temp 0.0 --top-k 0 --top-p 1.0 --min-p 0.0
            -rea off --reasoning-format none
          '';

          # Bash-command safety classifier.
          cmd-gate.cmd = ''
            ${llama-server} --port ''${PORT}
            -hf Qwen/Qwen3-4B-GGUF --hf-file Qwen3-4B-Q4_K_M.gguf
            ${gpu} ${perf} ${srv} ${gateSampling}
            -b 1024 -ub 512
            -c 8192 -n 192
            -rea off --reasoning-format none
          '';

          # General reasoning helper.
          ornith.cmd = ''
            ${llama-server} --port ''${PORT}
            -hf deepreinforce-ai/Ornith-1.0-9B-GGUF --hf-file ornith-1.0-9b-Q4_K_M.gguf
            ${gpu} ${perf} ${srv} ${gateSampling}
            -b 1024 -ub 512
            -c 262144 -n -1
            -rea on --reasoning-budget -1 --reasoning-format deepseek --reasoning-preserve
          '';
        };

        # Load zeta at boot so it is the default resident model.
        hooks.on_startup.preload = [ "zeta" ];
      };
    };
  };

  # The llama-swap module runs as a hardened DynamicUser. Relax the bits that
  # break Vulkan and give it a writable cache for HF downloads / shader cache.
  systemd.services.llama-swap = {
    serviceConfig = {
      SupplementaryGroups = [ "video" "render" ];
      MemoryDenyWriteExecute = pkgs.lib.mkForce false;
      CacheDirectory = "llama-swap";
    };
    environment = {
      HOME = "/var/cache/llama-swap";
      XDG_CACHE_HOME = "/var/cache/llama-swap";
      HF_HOME = "/var/cache/llama-swap/huggingface";
      MESA_SHADER_CACHE_DIR = "/var/cache/llama-swap";
    };
  };
}
