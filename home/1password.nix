{ config, lib, pkgs, ... }: let
  lock = "${pkgs._1password-gui}/bin/1password --lock --silent";
  ssh-key = "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAINMUrtMAAGoiU1XOUnw2toDLMKCrhWXPuH8VY9X79IRj";
in {
  programs = {
    ssh = {
      extraConfig = ''
      Host *
          IdentityAgent ~/.1password/agent.sock
      '';
    };

    git = {
      extraConfig = {
        gpg = {
          format = "ssh";
          "ssh".program = "${pkgs._1password-gui}/bin/op-ssh-sign";
        };
      };
      signing = {
        key = ssh-key;
        signByDefault = true;
      };
    };

    jujutsu.settings.signing = {
      backend = "ssh";
      key = ssh-key;
      backends.ssh.program = "${pkgs._1password-gui}/bin/op-ssh-sign";
    };
  };

  services.swayidle = lib.mkIf config.services.swayidle.enable {
    events = [
      { event = "before-sleep"; command = lock;}
    ];
    timeouts = [
      { timeout = 300; command = lock;}
    ];
  };

  systemd.user.services._1password-tray = {
    Unit = {
      Description = "1password Tray";
      Requires = [ "tray.target" ];
      After = [ "tray.target" ];
    };

    Service.ExecStart = "${pkgs._1password-gui}/bin/1password --silent";
    # Install.WantedBy = [ "graphical-session.target" ];
  };
}
