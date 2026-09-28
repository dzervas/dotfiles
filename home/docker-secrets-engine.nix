{
  config,
  lib,
  pkgs,
  ...
}:
let
  configureDockerCredentials = pkgs.writeShellScript "configure-docker-credentials" ''
    set -euo pipefail

    configDir=${lib.escapeShellArg "${config.home.homeDirectory}/.docker"}
    configFile="$configDir/config.json"

    if [ -L "$configFile" ]; then
      echo "Docker config is a symlink; configure credsStore in its source instead" >&2
      exit 1
    fi

    if [ -f "$configFile" ] && ${pkgs.jq}/bin/jq -e '.credsStore == "secretservice"' "$configFile" >/dev/null; then
      exit 0
    fi

    ${pkgs.coreutils}/bin/mkdir -p "$configDir"
    tmp=$(${pkgs.coreutils}/bin/mktemp "$configDir/.config.json.XXXXXX")
    trap '${pkgs.coreutils}/bin/rm -f "$tmp"' EXIT

    if [ -f "$configFile" ]; then
      ${pkgs.jq}/bin/jq '.credsStore = "secretservice"' "$configFile" > "$tmp"
    else
      printf '%s\n' '{"credsStore":"secretservice"}' > "$tmp"
    fi

    ${pkgs.coreutils}/bin/mv "$tmp" "$configFile"
  '';
in
{
  home.packages = with pkgs; [
    docker-secrets-engine
    docker-credential-helpers
  ];

  home.activation.configureDockerCredentials = lib.hm.dag.entryAfter [ "writeBoundary" ] ''
    run ${configureDockerCredentials}
  '';

  systemd.user.services = {
    docker-secrets-engine = {
      Unit = {
        Description = "Docker Secrets Engine";
        After = [ "graphical-session.target" ];
        PartOf = [ "graphical-session.target" ];
      };
      Service = {
        ExecStart = "${pkgs.docker-secrets-engine}/bin/secrets-engine";
        Restart = "on-failure";
      };
      Install.WantedBy = [ "graphical-session.target" ];
    };

    # MCP Gateway v0.43.3 expects Desktop's engine.sock, while the standalone
    # daemon listens on an abstract per-user daemon.sock.
    # TODO: Use 1password
    docker-mcp-secrets-socket = {
      Unit = {
        Description = "Docker MCP Secrets Engine socket bridge";
        Requires = [ "docker-secrets-engine.service" ];
        After = [ "docker-secrets-engine.service" ];
        PartOf = [ "graphical-session.target" ];
      };
      Service = {
        ExecStartPre = "${pkgs.coreutils}/bin/mkdir -p %h/.cache/docker-secrets-engine";
        ExecStart = "${pkgs.socat}/bin/socat UNIX-LISTEN:%h/.cache/docker-secrets-engine/engine.sock,mode=0600,unlink-early,fork ABSTRACT-CONNECT:docker-secrets-engine/%U/daemon.sock";
        Restart = "on-failure";
      };
      Install.WantedBy = [ "graphical-session.target" ];
    };
  };
}
