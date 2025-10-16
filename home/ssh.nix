{ pkgs, ... }: {
  programs.ssh = {
    enable = true;
    includes = ["~/.ssh/local.ssh.cfg"];
    enableDefaultConfig = false;
    matchBlocks = rec {
      "*" = {
        addKeysToAgent = "confirm";
        compression = false;
        controlMaster = "no";
        controlPersist = "no";
        forwardAgent = false;
        hashKnownHosts = false;
        # identitiesOnly = true;
        # identityAgent = "none";
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

      "*.dzerv.art".user = "root";

      # NOTE: To force order use lib.hm.dag.entryBefore ["entry"] { newstuff }
    };
  };

  services.ssh-agent.enable = true;
  systemd.user.services.ssh-agent.Service.Environment = [
    "SSH_ASK_PASS=${pkgs.wayprompt}/bin/wayprompt-ssh-askpass"
  ];
  # services.yubikey-agent.enable = true;

  # yubikey-agent uses the gpg-agent pinentry to ask for the PIN
  # services.gpg-agent = {
  #   enable = true;
  #   pinentry.package = pkgs.pinentry-qt;
  # };

  home.packages = with pkgs; [
    yubikey-manager
    pinentry-qt
    gcr
  ];

  # To set up a new yubikey:
  # ssh-keygen -t ed25519-sk -O resident -O verify-required -O application=ssh:dzervas -C "dzervas@$(hostname)" -f ~/.ssh/yubikey_$(hostname)
  # To retrieve the resident private keys (stubs that include metadata): ssh-keygen -K
}
