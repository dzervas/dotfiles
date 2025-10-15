{ pkgs, ... }: {
  programs.ssh = {
    enable = true;
    includes = ["~/.ssh/local.ssh.cfg"];
    enableDefaultConfig = false;
    matchBlocks = rec {
      "*" = {
        addKeysToAgent = "no";
        compression = false;
        controlMaster = "no";
        controlPersist = "no";
        forwardAgent = false;
        hashKnownHosts = false;
        # identityAgent = "/run/user/1000/ssh-agent"; # Default for the ssh-agent service, defaults to gnome-keyring if not set
        serverAliveInterval = 60;
        serverAliveCountMax = 30;
        userKnownHostsFile = "~/.ssh/known_hosts";
      };

      # Aliases
      gh = {
        hostname = "github.com";
        user = "git";
      };
      github = gh;
      "github.com" = gh;

      raspberrypi = {
        hostname = "raspberrypi.local";
        user = "pi";
      };

      "*.dzerv.art" = {
        user = "root";
        # extraOptions.Tag = "sessioned";
      };

      # NOTE: To force order use lib.hm.dag.entryBefore ["entry"] { newstuff }
    };
  };

  services.ssh-agent.enable = true;

  home.packages = with pkgs; [
    yubikey-manager
    pinentry-qt
    gcr
  ];

  # To set up a new yubikey:
  # ssh-keygen -t ed25519-sk -O resident -O verify-required -C "$(g config user.email)" -f ~/.ssh/yubikey_<name>
  # To retrieve the resident private keys (stubs that include metadata): ssh-keygen -K
}
