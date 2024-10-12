{ pkgs, ... }: {
  environment.systemPackages = with pkgs; [
    bat
    colordiff
    cyme # Better lsusb!
    difftastic
    dig
    fd
    file
    fzf
    git
    htop
    ijq
    jq
    killall
    libnotify # For notify-send
    lsd
    ngrok
    p7zip
    podman-compose
    python3Packages.python
    readline
    ripgrep
    socat
    statix # Lint nix files
    tree
    unzip
    usbutils
    wget
  ];

  # Set fish as the default shell
  programs.fish.enable = true;

  services.locate = {
    enable = true;
    localuser = null;
    package = pkgs.plocate;
  };

  virtualisation.podman = {
    enable = true;
    dockerCompat = true;
    autoPrune.enable = true;
    dockerSocket.enable = true;
  };
  virtualisation.containers.registries.search = [ "docker.io" ];

  security = {
    pam.services.kwallet = {
      name = "kwallet";
      enableKwallet = true;
    };
  };

  environment.shellAliases = {
    # Quick aliases for common commands
    "1ping" = "ping 1.1.1.1";
    c = "cargo";
    cdt = "cd $(mktemp -d)";
    d = "docker";
    dc = "docker-compose";
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
    pc = "podman-compose";
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
    docker_rm = "docker rm $(docker ps --no-trunc -aqf status=exited)";
    docker_rmi = "docker rmi $(docker images --no-trunc -qf dangling=true)";
    open = "xdg-open";
    passgen = "gpg --armor --gen-random 2 ";
    reboot = "read -P 'Are you sure?' && systemctl reboot";
    weather = "curl wttr.in";
    webserver = "python3 -m http.server";

    # Hipster tools
    cat = "bat -p --style=header-filename,header-filesize,snip --paging=never";
    diff = "colordiff -ub";
    grep = "rg";
    less = "bat -p --color=always";
    ll = "lsd -Fal";
    ls = "lsd -F";
    lsusb = "cyme";
    find = "fd";
  };
}
