{ pkgs, ... }: let
  atuin-port = "55888";
  atuin-script = pkgs.writeShellScript "atuin-daemon.sh" ''
set -euo pipefail

echo "Starting atuin port forwarding..."
${pkgs.kubectl}/bin/kubectl port-forward --context=gr --namespace=atuin --address=127.0.0.1 svc/atuin ${atuin-port}:8888 &
DAEMON_PID=$!

for i in $(seq 1 30); do
  netstat -tulpn 2>&1 | grep 127.0.0.1:${atuin-port} && break
  echo "Port forward not up yet, waiting 10s"
  sleep 10
done

if [ $i -gt 29 ]; then
  echo "Port forward failed to start after 5 minutes, exiting"
  exit 1
fi

echo "Starting atuin daemon..."
${pkgs.atuin}/bin/atuin daemon
echo "Atuin daemon exited, killing port forward"
kill $DAEMON_PID
'';
in {
  programs.atuin = {
    enable = true;
    flags = [ "--disable-up-arrow" ];
    # daemon.enable = true;
    settings = {
      enter_accept = false;
      sync_address = "http://127.0.0.1:${atuin-port}";
      sync_frequency = "5m";
      sync.records = true;

      history_filter = [
        # Ignore space-prefixed commands
        "^\s+"
      ];

      # daemon.systemd_socket = true;
    };
  };

  systemd.user.services.atuin-daemon = {
    Unit = {
      Description = "Atuin daemon";
      After = ["network-online.target"];
      Wants = ["network-online.target"];
    };
    Install = {
      WantedBy = [ "multi-user.target" ];
    };
    Service = {
      ExecStart = atuin-script;
      Restart = "on-failure";
      RestartSteps = 3;
      RestartMaxDelaySec = 6;

      # Environment = ["ATUIN_CONFIG_DIR=/etc/atuin"];
      # ReadWritePaths = ["/etc/atuin"];

      # Hardening options
      CapabilityBoundingSet = [];
      AmbientCapabilities = [];
      NoNewPrivileges = true;
      # ProtectHome = true;
      ProtectSystem = "strict";
      ProtectKernelTunables = true;
      ProtectKernelModules = true;
      ProtectControlGroups = true;
      PrivateTmp = true;
      PrivateDevices = true;
      LockPersonality = true;
    };
  };
}
