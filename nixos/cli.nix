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

  services.locate = {
    enable = true;
    package = pkgs.plocate;
  };

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

  services.udev.extraRules = ''
    # Add support for the thermal printer
    SUBSYSTEM=="usb", ATTRS{idVendor}=="4b43", ATTRS{idProduct}=="3538", MODE="0660", GROUP="dialout"
  '';

  # TODO: Do we want to allow user-based keeb config?
  # Non-root access to the qmk
  hardware.keyboard.qmk.enable = true;

  services.llama-cpp = let
  #   modelPreset = (pkgs.formats.ini { }).generate "llama-models.ini" {
  #   "*" = {
  #     ctx-size = 8192;
  #     n-predict = 192;
  #     threads = 16;
  #     threads-batch = 16;
  #     batch-size = 1024;
  #     ubatch-size = 256;
  #     flash-attn = "on";
  #     cache-type-k = "q8_0";
  #     cache-type-v = "q8_0";
  #     cache-prompt = true;
  #     parallel = 1;
  #     reasoning = "off";
  #     temp = 0.1;
  #     top-k = 20;
  #     top-p = 0.8;
  #     min-p = 0.0;
  #   };
  #
  #   "qwen3-1.7b" = {
  #     model = "Qwen/Qwen3-1.7B-GGUF:Q4_K_M";
  #     alias = "cmd-gate-fast";
  #   };
  #   "qwen3-4b" = {
  #     model = "Qwen/Qwen3-4B-GGUF:Q4_K_M";
  #     alias = "cmd-gate";
  #   };
  # };
  in
  {
    enable = true;
    port = 1337;
    package = pkgs.llama-cpp-vulkan;

    settings = {
      hf-repo = "deepreinforce-ai/Ornith-1.0-9B-GGUF";
      hf-file = "ornith-1.0-9b-Q4_K_M.gguf";
      alias = "ornith";

      # Ornith advertises a 262k training context; this is the max context.
      ctx-size = 262144;
      n-predict = 192;

      # 5950X: physical cores first. SMT often does not help token generation.
      threads = 16;
      threads-batch = 16;

      # Best measured max-context prefill on this machine; generation is within noise.
      batch-size = 1024;
      ubatch-size = 512;

      # CPU only
      # gpu-layers = 0;
      # flash-attn = "on";

      # For GPU:
      gpu-layers = "all";
      split-mode = "none";
      main-gpu = 0;
      fit = "on";
      fit-target = 1024;
      flash-attn = "on";
      cache-type-k = "q8_0";
      cache-type-v = "q8_0";
      kv-offload = true;

      # Server behavior.
      parallel = 1;
      cont-batching = true;
      cache-prompt = true;
      cache-reuse = 256;
      metrics = true;
      slots = true;
      timeout = 30;

      # Keep reasoning disabled for low-latency helper usage.
      reasoning = "off";
      reasoning-format = "none";

      # Classification sampling. Low temp because this is a policy helper, not chat.
      seed = 42;
      temp = 0.1;
      top-k = 20;
      top-p = 0.8;
      min-p = 0.0;
      repeat-penalty = 1.0;
      presence-penalty = 0.0;
      frequency-penalty = 0.0;
    };
  };

  # Vulkan shader cache fix that is commonly needed with the NixOS service.
  systemd.services.llama-cpp.environment = {
    XDG_CACHE_HOME = "/var/cache/llama-cpp";
    MESA_SHADER_CACHE_DIR = "/var/cache/llama-cpp";
  };

  systemd.tmpfiles.rules = [
    "d /var/cache/llama-cpp 0755 llama-cpp llama-cpp -"
  ];
}
