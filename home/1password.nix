{ config, lib, pkgs, ... }: let
  lock = "${pkgs._1password-gui}/bin/1password --lock --silent";
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
        key = "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAINMUrtMAAGoiU1XOUnw2toDLMKCrhWXPuH8VY9X79IRj";
        signByDefault = true;
      };
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
      PartOf = [ "graphical-session.target" ];
      Requires = [ "tray.target" ];
      After = [
        "graphical-session-pre.target"
        "tray.target"
      ];
    };

    Service.ExecStart = "${pkgs._1password-gui}/bin/1password --silent --enable-features=UseOzonePlatform --ozone-platform-hint=auto --ozone-platform=wayland";
    Install.WantedBy = [ "graphical-session.target" ];
  };

  opnix = {
    # OP_SERVICE_ACCOUNT_TOKEN="{your token here}"
    environmentFile = "${config.home.homeDirectory}/.1password/opnix.env";
    # Set the systemd services that will use 1Password secrets; this makes them wait until
    # secrets are deployed before attempting to start the service.
    systemdWantedBy = ["restic"];
    secrets = {
      rclone = {
        mode = "0600"; # We need rclone to be able to write the tokens
        source = ''
        [backup]
        type = onedrive
        drive_type = business
        access_scopes = Files.ReadWrite.AppFolder Sites.Read.All offline_access
        no_versions = true
        hard_delete = true
        av_override = true
        metadata_permissions = read,write

        auth_url = https://login.microsoftonline.com/{{ op://Nix/restic/tenant_id }}/oauth2/v2.0/authorize
        token_url = https://login.microsoftonline.com/{{ op://Nix/restic/tenant_id }}/oauth2/v2.0/token
        client_id = {{ op://Nix/restic/client_id }}
        client_secret = {{ op://Nix/restic/client_secret }}
        drive_id = {{ op://Nix/restic/drive_id }}
        '';
      };
    };
  };
}
