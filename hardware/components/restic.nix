{ config, pkgs, ... }: let
  homedir = "/home/dzervas";
in {
  environment = {
    sessionVariables = {
      RESTIC_REPOSITORY = "rclone:backup:/rclone/backups/desktop";
      RESTIC_PASSWORD_COMMAND = "op read op://Nix/restic/password";
    };
    systemPackages = with pkgs; [
      rclone
      restic
    ];
  };

  services.restic.backups = {
    documents = {
      paths = [
        "${homedir}/Documents"
        "${homedir}/.BurpSuite/UserConfigPro.json"
        "${homedir}/.java/.userPrefs"
        "${homedir}/.var/app/org.ryujinx.Ryujinx/config/Ryujinx/bis/user"
        "${homedir}/.binaryninja"
      ];

      exclude = [
        "home/*/.java/.userPrefs/.user.lock.*"
        "home/*/.java/.userPrefs/*/.user.lock.*"
      ];

      timerConfig = {
        OnCalendar = "*:00:00/6";
        Persistent = true;
      };
      pruneOpts = [
        "--keep-daily 7"
        "--keep-weekly 5"
        "--keep-monthly 12"
        "--keep-yearly 75"
      ];

      runCheck = true;
      repository = "rclone:backup:/rclone/backups/desktop";
      passwordFile = config.opnix.secrets.restic.path;
      rcloneConfigFile = "/etc/rclone/rclone.conf";
    };
  };

  opnix = {
    environmentFile = "/etc/opnix.env"; # contents: OP_SERVICE_ACCOUNT_TOKEN="{your token here}"
    # Set the systemd services that will use 1Password secrets; this makes them wait until
    # secrets are deployed before attempting to start the service.
    systemdWantedBy = ["restic-backups-documents"];
    secrets = {
      restic.source = "{{ op://Nix/restic/password }}";
    };
  };
}
