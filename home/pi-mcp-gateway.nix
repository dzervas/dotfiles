{ config, lib, pkgs, ... }: let
  # ------------------------------------------------------------------ servers
  # The single source of truth. Everything below is generated from this list:
  # the gateway catalog, the tool allowlist, and pi's mcp.json.
  #
  # A server is served by the gateway unless it sets `pi = true`, in which case it
  # is written straight into pi's mcp.json with pi's own schema (url/headers or
  # command/args/env). Pi entries cannot use `secrets`: `docker mcp secret` has no
  # get, so the keychain is unreachable from mcp.json — pass credentials as an
  # environment variable instead.
  servers = [
    {
      name = "vresto";
      title = "VresTo";
      description = "Web search, fetch, research and crawler";
      pi = true;
      exposure = "direct";
      url = "https://mcp.vpn.dzerv.art/vresto";
    }

    {
      name = "nixos";
      title = "NixOS";
      description = "NixOS package and option documentation";
      image = "ghcr.io/utensils/mcp-nixos:latest";
    }

    {
      name = "context7";
      title = "Context7";
      description = "Up-to-date, version-specific library documentation and code examples";
      pi = true;
      # Pi does not enforce RFC 9728 §3.3, so Context7's OAuth works here even
      # though the gateway rejects it. Sign in once: pi mcp login context7
      url = "https://mcp.context7.com/mcp/oauth";
    }
  ];
  # ------------------------------------------------------------------ end

  gatewayServers = lib.filter (s: !s.pi or false) servers;
  piServers = lib.filter (s: s.pi or false) servers;

  # A pi mcp.json entry. `command` is one executable and `args` its arguments.
  piEntry = s:
  { inherit (s) description; exposure = s.exposure or "codemode"; }
  // lib.optionalAttrs (s.url or null != null) { inherit (s) url; }
  // lib.optionalAttrs (s.headers or null != null) { inherit (s) headers; }
  // lib.optionalAttrs (s.command or null != null) { inherit (s) command; args = s.args or []; }
  // lib.optionalAttrs (s.env or null != null) { inherit (s) env; }
  // lib.optionalAttrs (s.toolExposure or null != null) { inherit (s) toolExposure; };

  yaml = pkgs.formats.yaml {};
  json = pkgs.formats.json {};
  mcpDir = "${config.home.homeDirectory}/.docker/mcp";

  # A catalog file is a `registry:` map of server entries (pkg/catalog/types.go
  # `topLevel`), not a bare server definition.
  entry = s:
  { inherit (s) name title description; type = s.type or "server"; }
  // lib.optionalAttrs (s.image or null != null) { inherit (s) image; }
  // lib.optionalAttrs (s.remote or null != null) { inherit (s) remote; }
  // lib.optionalAttrs (s.command or null != null) { inherit (s) command; }
  // lib.optionalAttrs (s.volumes or null != null) { inherit (s) volumes; }
  // lib.optionalAttrs (s.secrets or null != null) { inherit (s) secrets; }
  // lib.optionalAttrs (s.env or {} != {}) {
    env = lib.mapAttrsToList (name: value: { inherit name value; }) s.env;
  }
  // lib.optionalAttrs (s.allowHosts or null != null) { inherit (s) allowHosts; };

  catalog = yaml.generate "pi.yaml" {
    registry = lib.listToAttrs (
      map (s: { inherit (s) name; value = entry s; }) gatewayServers
    );
  };

  # tools.yaml is a flat per-server allowlist (ServerTools map[string][]string,
  # yaml:",inline"). A server with no entry keeps all of its tools, so only
  # servers that name a tool list appear here.
  tools = yaml.generate "pi-tools.yaml" (
    lib.listToAttrs (
      map (s: {
        inherit (s) name;
        value = s.tools;
      }) (lib.filter (s: s.tools or null != null) gatewayServers)
    )
  );

  # The gateway appears as one server, so its description lists every gateway
  # server. Servers with `pi = true` are separate entries in the same file.
  mcpJson = json.generate "mcp.json" {
    mcpServers = {
      mcp-gateway = {
        url = "http://127.0.0.1:8811/mcp";
        headers.Authorization = "!cat ~/.cache/pi-mcp-gateway/authorization";
        description = lib.concatMapStringsSep ", " (s: s.description) gatewayServers;
        exposure = "codemode";
        toolExposure = lib.listToAttrs (
          lib.concatMap (
            s:
            map (t: { name = t; value = "direct"; }) (s.direct or [])
          ) gatewayServers
        );
      };
    }
    // lib.listToAttrs (
      map (s: { inherit (s) name; value = piEntry s; }) piServers
    );
  };

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
in {
  # Catalog paths must resolve under ~/.docker/mcp/catalogs/, tools paths under
  # ~/.docker/mcp/, so materialize them instead of symlinking to /nix/store.
  home.activation.installPiMcpFiles = lib.hm.dag.entryAfter [ "writeBoundary" ] ''
    run ${pkgs.coreutils}/bin/install -Dm644 ${catalog} ${lib.escapeShellArg "${mcpDir}/catalogs/pi.yaml"}
    run ${pkgs.coreutils}/bin/install -Dm644 ${tools} ${lib.escapeShellArg "${mcpDir}/pi-tools.yaml"}
  '';

  # Generated, so pi's /mcp cannot write exposure changes back to it: a store
  # file is read-only. Keep the list as the place to change exposure.
  home.file.".pi/agent/mcp.json".source = mcpJson;

  systemd.user.services.pi-mcp-gateway = {
    Unit = {
      Description = "Docker MCP pi profile for Pi";
      Requires = [ "docker.service" ];
      After = [ "docker.service" ];
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
        # --profile is mutually exclusive with --servers, so the profile is not
        # used: profiles live in ~/.docker/mcp/mcp-toolkit.db (SQLite) and cannot
        # be generated. These flags are the declarative path.
        "--catalog"
        "${mcpDir}/catalogs/pi.yaml"
        "--servers"
        (lib.concatMapStringsSep "," (s: s.name) gatewayServers)
        "--tools-config"
        "${mcpDir}/pi-tools.yaml"
        "--transport"
        "streaming"
        "--host"
        "127.0.0.1"
        "--port"
        "8811"
        "--log-calls=false"
      ];
      Restart = "on-failure";
      RestartSec = 3;
      UMask = "0077";
    };
    Install.WantedBy = [ "default.target" ];
  };
}
