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
      docker-mcp
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
      yq-go

      nix-serve-ng
      rust-script
    ];

    # Docker's Nix wrapper searches the directories in this variable for CLI plugins.
    sessionVariables.DOCKER_CLI_PLUGIN_DIRS = "${pkgs.docker-mcp}/libexec/docker/cli-plugins:${pkgs.docker-secrets-engine}/libexec/docker/cli-plugins";

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
      docker-prune = ''
        docker system df && \
        podman system df && \
        podman system prune -a && \
        podman container prune && \
        docker container prune && \
        docker image prune -a --filter 'until=168h' -f && \
        podman system prune -a --filter 'until=168h' -f && \
        docker builder prune && \
        docker volume prune && \
        podman volume prune && \
        docker system df && \
        podman system df
      '';
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

    etc."codex/requirements.toml".source = pkgs.writers.writeTOML "requirements.toml" {
      allowed_approval_policies = [ "never" "on-request" ];
      default_permissions = "sandboxed";
      # allowed_permission_profiles = { sandboxed = true; ":danger-full-access" = true; };
      allowed_permission_profiles = { sandboxed = true; };

      allow_managed_hooks_only = true;
      allowed_approvals_reviewers = ["user"];
      browser_use.allow_history_access = false;
      check_for_update_on_startup = false;
      features.computer_use = false;
      feedback.enabled = false;

      permissions.sandboxed = {
        extends = ":workspace";
        network.enabled = true;
        filesystem = {
          glob_scan_max_depth = 8;

          # Deny everything first
          ":root" = "deny";
          ":slash_tmp" = "deny";

          # NixOS runtime/toolchain
          "/nix/store" = "read";
          "/run/binfmt" = "read";
          "/run/current-system/sw" = "read";
          "/bin" = "read";
          "/usr/bin" = "read";

          "/etc" = "read";

          # tooling/config
          "~/.config/gcx" = "write";
          "~/.config/jj" = "read";
          "~/.config/git" = "read";
          "~/.config/fish" = "read";
          "~/.codex/packages" = "read";
        };
      };
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
