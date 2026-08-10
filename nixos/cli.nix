{ pkgs, ... }:
{
  environment = {
    systemPackages = with pkgs; [
      bat
      binutils
      btop
      colordiff
      cyme # Better lsusb!
      difftastic
      dig
      dmidecode
      docker-sbx
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

    shellAliases = {
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
  };

  # Set fish as the default shell
  programs.fish.enable = true;

  virtualisation = {
    containers = {
      enable = true;
      registries.search = [ "docker.io" ];
    };

    docker = {
      enable = true;
      storageDriver = "btrfs";

      autoPrune = {
        enable = true;
        allVolumes.enable = true;
      };

      rootless = {
        enable = true;
        setSocketVariable = true;
      };
    };
  };

  security = {
    pam.services.kwallet = {
      name = "kwallet";
      enableKwallet = true;
    };
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
  };
}
