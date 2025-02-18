{ pkgs, ... }: let
  atuin-port = "55888";
  atuin-script = pkgs.writeShellScript "atuin-daemon.sh" ''
set -euo pipefail
echo "Starting atuin port forwarding..."
${pkgs.kubectl}/bin/kubectl port-forward --context=gr --namespace=atuin --address=127.0.0.1 svc/atuin ${atuin-port}:8888 &
PF_PID=$!
sleep 2
echo "Starting atuin daemon..."
${pkgs.atuin}/bin/atuin daemon &
DAEMON_PID=$!
wait $PF_PID
echo "Port forwarding stopped, killing daemon..."
kill $DAEMON_PID
wait $DAEMON_PID

exit 1
  '';
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

  systemd.user.services.atuin-daemon.Service.ExecStart = [atuin-script];
}
