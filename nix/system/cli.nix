{ pkgs, ... }: {
  environment.systemPackages = with pkgs; [
    _7zz
    bat
    colordiff
    difftastic
    dig
    fd
    fzf
    git
    htop
    jq
    killall
    libnotify # For notify-send
    lsd
    ngrok
    (python3Packages.python.withPackages (p: [ p.ipython ]))
    ripgrep
    unzip
  ];

  # Set fish as the default shell
  programs.fish.enable = true;

  virtualisation.podman = {
    enable = true;
    dockerCompat = true;
    autoPrune.enable = true;
    dockerSocket.enable = true;
  };

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
    jc = "curl -H \"Content-Type: application/json\"";
    k = "kubectl";
    kn = "kubens";
    kc = "kubectx";
    l = "locate -i";
    lp = "locate -i -A \"$(pwd)\"";
    n = "echo -e \"\a\" && notify-send -a \"Terminal\" Notification!";
    p = "podman";
    pc = "podman-compose";
    py = "python";
    v = "nvim";
    sv = "sudoedit";
    tf = "terraform";

    # Nicer output
    man = "LC_ALL=C LANG=C command man";
    pgrep = "command pgrep -af";
    ssh = "TERM=xterm-256color command ssh";
    now = "date +\"%Y.%m.%d-%H.%M.%S\"";
    # By https://unix.stackexchange.com/questions/25327/watch-command-alias-expansion
    watch = "command watch -c ";

    # Useful aliases
    docker_rm = "docker rm $(docker ps --no-trunc -aqf status=exited)";
    docker_rmi = "docker rmi $(docker images --no-trunc -qf dangling=true)";
    open = "xdg-open";
    passgen = "gpg --armor --gen-random 2 ";
    weather = "curl wttr.in";
    webserver = "python3 -m http.server";

    # Hipster tools
    cat = "bat -p --paging=never";
    diff = "colordiff -ub";
    grep = "rg";
    less = "bat -p";
    ll = "lsd -Fal";
    ls = "lsd -F";
    find = "fd";
  };
}
