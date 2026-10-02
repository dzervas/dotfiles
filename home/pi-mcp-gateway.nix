{
  config,
  lib,
  pkgs,
  ...
}:
let
  gatewayDir = "${config.home.homeDirectory}/.cache/pi-mcp-gateway";
  catalogPath = "${config.home.homeDirectory}/.docker/mcp/catalogs/pi-fixed.yaml";
  # Only this declarative set can be started by the gateway. No host mounts.
  servers.nixos = {
    title = "NixOS";
    description = "NixOS package and option documentation";
    type = "server";
    image = "ghcr.io/utensils/mcp-nixos:latest";
  };
  catalog = (pkgs.formats.yaml { }).generate "pi-mcp-catalog.yaml" { registry = servers; };
  prepareAuth = pkgs.writeShellScript "pi-mcp-gateway-auth" ''
    exec ${pkgs.python3}/bin/python3 - ${lib.escapeShellArg gatewayDir} <<'PY'
    import os
    import secrets
    import sys
    from pathlib import Path

    os.umask(0o077)
    directory = Path(sys.argv[1])
    directory.mkdir(parents=True, exist_ok=True, mode=0o700)
    environment = directory / "environment"
    authorization = directory / "authorization"
    if not environment.exists() or not authorization.exists():
        token = secrets.token_urlsafe(32)
        environment.write_text(f"MCP_GATEWAY_AUTH_TOKEN={token}\n")
        authorization.write_text(f"Bearer {token}\n")
    PY
  '';
in
{
  # The CLI validates catalog paths, so materialize it instead of symlinking to /nix/store.
  home.activation.installPiMcpCatalog = lib.hm.dag.entryAfter [ "writeBoundary" ] ''
    run ${pkgs.coreutils}/bin/install -Dm644 ${catalog} ${lib.escapeShellArg catalogPath}
  '';

  systemd.user.services.pi-mcp-gateway = {
    Unit = {
      Description = "Fixed Docker MCP servers for Pi";
      Requires = [ "docker.service" ];
      After = [ "docker.service" ];
    };
    Service = {
      Environment = [
        "DOCKER_HOST=unix://%t/docker.sock"
        "DOCKER_CLI_PLUGIN_DIRS=${pkgs.docker-mcp}/libexec/docker/cli-plugins"
        "DOCKER_MCP_IN_CONTAINER=1"
      ];
      EnvironmentFile = "-${gatewayDir}/environment";
      ExecStartPre = prepareAuth;
      # --servers also disables the gateway's dynamic server-management tools.
      ExecStart = lib.escapeShellArgs [
          "${pkgs.docker}/bin/docker"
          "mcp"
          "gateway"
          "run"
          "--servers"
          (lib.concatStringsSep "," (builtins.attrNames servers))
          "--catalog"
          catalogPath
          "--transport"
          "streaming"
          "--host"
          "127.0.0.1"
          "--port"
          "8811"
          "--watch=false"
          "--log-calls=false"
        ];
      Restart = "on-failure";
      RestartSec = 3;
      UMask = "0077";
    };
    Install.WantedBy = [ "default.target" ];
  };
}
