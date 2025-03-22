{ pkgs, ... }: let
  atuin-port = "55888";
  atuin-script = pkgs.writeShellScript "atuin-daemon.sh" ''
set -euo pipefail
echo "Starting atuin daemon..."
${pkgs.atuin}/bin/atuin daemon &
DAEMON_PID=$!

while true; do
  echo "Starting atuin port forwarding..."
  ${pkgs.kubectl}/bin/kubectl port-forward --context=gr --namespace=atuin --address=127.0.0.1 svc/atuin ${atuin-port}:8888 || true
  echo "Port forward got killed, waiting a bit"
  sleep 600
done
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
