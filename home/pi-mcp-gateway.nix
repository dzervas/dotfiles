{
  config,
  lib,
  pkgs,
  ...
}:
let
  gatewayDir = "${config.home.homeDirectory}/.cache/pi-mcp-gateway";
  # Gateway v0.44.1 drops DOCKER_HOST from stdio children, but preserves PATH.
  # Keep the workaround service-local until upstream forwards Docker's environment.
  # The gateway runs standalone: nixpkgs' docker wrapper would prepend its
  # libexec/docker (containing the real CLI) to PATH and shadow this one.
  # Profile secrets reach containers as se:// references, which only Docker
  # Desktop resolves; docker pass run resolves them for plain Docker. It finds
  # the engine socket under ~/.cache, but the gateway strips HOME as well.
  rootlessDocker = pkgs.writeShellScriptBin "docker" ''
    export HOME=${lib.escapeShellArg config.home.homeDirectory}
    exec ${pkgs.docker-secrets-engine}/bin/docker-pass run -- \
      ${pkgs.docker}/bin/docker \
      --host "unix:///run/user/$(${pkgs.coreutils}/bin/id -u)/docker.sock" "$@"
  '';
  # Built by docker-mcp-builder.nix.
  kagiImage = "kagi-mcp:local";
  kagiServerPath = "${config.home.homeDirectory}/.docker/mcp/catalogs/pi-kagi.yaml";
  kagiServer = (pkgs.formats.yaml { }).generate "pi-kagi.yaml" {
    name = "kagi";
    title = "Kagi";
    type = "server";
    image = kagiImage;
    description = "Kagi search, summarize, extract, quick answer and news";
    secrets = [
      {
        name = "kagi.session_token";
        env = "KAGI_SESSION_TOKEN";
      }
    ];
  };
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
  # The CLI rejects server files that resolve outside its catalog directory, so
  # materialize it instead of symlinking to /nix/store.
  home.activation.installPiKagiServer = lib.hm.dag.entryAfter [ "writeBoundary" ] ''
    run ${pkgs.coreutils}/bin/install -Dm644 ${kagiServer} ${lib.escapeShellArg kagiServerPath}
  '';

  systemd.user.services.pi-mcp-gateway = {
    Unit = {
      Description = "Docker MCP pi profile for Pi";
      Requires = [ "docker.service" ];
      # Kagi is optional; a failed image build must not block the other servers.
      Wants = [ "docker-mcp-builder.service" ];
      After = [
        "docker.service"
        "docker-mcp-builder.service"
      ];
    };
    Service = {
      Environment = [
        "DOCKER_HOST=unix://%t/docker.sock"
        "PATH=${rootlessDocker}/bin:${config.home.profileDirectory}/bin:/run/current-system/sw/bin"
        "DOCKER_CLI_PLUGIN_DIRS=${pkgs.docker-mcp}/libexec/docker/cli-plugins"
        "DOCKER_MCP_IN_CONTAINER=1"
      ];
      EnvironmentFile = "-${gatewayDir}/environment";
      ExecStartPre = prepareAuth;
      ExecStart = lib.escapeShellArgs [
          "${pkgs.docker-mcp}/libexec/docker/cli-plugins/docker-mcp"
          "gateway"
          "run"
          "--profile"
          "pi"
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
