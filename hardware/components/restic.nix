{ config, pkgs, ... }: let
  homedir = "/home/dzervas";
in {
  environment.systemPackages = with pkgs; [
    rclone
    restic
  ];

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
        OnCalendar = "daily";
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
      rcloneConfigFile = "${homedir}/.config/rclone/rclone.conf";
    };
  };

  opnix = {
    # OP_SERVICE_ACCOUNT_TOKEN="{your token here}"
    environmentFile = "/etc/opnix.env";
    # Set the systemd services that will use 1Password secrets; this makes them wait until
    # secrets are deployed before attempting to start the service.
    systemdWantedBy = ["restic-backups-documents"];
    secrets = {
      restic.source = "{{ op://Nix/restic/password }}";
    };
  };
}
