{ pkgs, ... }: {
  programs.atuin = {
    enable = true;
    flags = [ "--disable-up-arrow" ];
    settings = {
      sync_address = "http://127.0.0.1:55888";
      enter_accept = false;
      history_filter = [
        # Ignore space-prefixed commands
        "^\s+"
      ];
    };
  };

  systemd.user.services.atuin-port-forward = {
    Unit = {
      Description = "Do a kubectl port-forward to the atuin service";
    };
    Install = {
      WantedBy = [ "default.target" ];
    };
    Service = {
      ExecStart = pkgs.writeShellScript "atuin-port-forward" ''
        #!/run/current-system/sw/bin/bash
        kubectl port-forward --context gr --namespace atuin --address 127.0.0.1 svc/atuin 55888:8888
      '';
    };
  };
}
