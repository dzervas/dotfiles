{ pkgs, ... }: let
  atuin-port = "55888";
in {
  programs.atuin = {
    enable = true;
    flags = [ "--disable-up-arrow" ];
    settings = {
      enter_accept = false;
      daemon.enabled = true;
      sync_address = "http://127.0.0.1:${atuin-port}";
      sync_frequency = "5m";
      sync.records = true;

      history_filter = [
        # Ignore space-prefixed commands
        "^\s+"
      ];
    };
  };

  systemd.user.services.atuin-port-forward = {
    Unit = {
      Description = "Do a kubectl port-forward to the atuin service";
      StartLimitBurst = 5;
      StartLimitIntervalSec = 300;
    };
    Install = {
      WantedBy = [ "default.target" ];
    };
    Service = {
      ExecStart = [
        "${pkgs.kubectl}/bin/kubectl port-forward --context=gr --namespace=atuin --address=127.0.0.1 svc/atuin ${atuin-port}:8888"
      ];
      Restart = "always";
      RestartSec = 60;
    };
  };


  systemd.user.services.atuind = {
    Unit = {
      Description = "Atuin daemon";
      StartLimitBurst = 5;
      StartLimitIntervalSec = 300;

      Requires = [ "atuin-port-forward.service" ];
    };
    Install = {
      WantedBy = [ "default.target" ];
    };
    Service = {
      ExecStart = [
        "${pkgs.atuin}/bin/atuin daemon"
      ];
      Restart = "always";
      RestartSec = 60;
    };
  };
}
