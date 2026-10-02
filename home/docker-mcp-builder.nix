{
  lib,
  pkgs,
  ...
}:
let
  # docker/Dockerfile.kagi-mcp -> kagi-mcp:local
  mcpDockerfiles = lib.mapAttrsToList (file: _: {
    name = lib.removePrefix "Dockerfile." file;
    file = ../docker + "/${file}";
  }) (lib.filterAttrs (
    file: type: type == "regular" && lib.hasPrefix "Dockerfile." file && lib.hasSuffix "-mcp" file
  ) (builtins.readDir ../docker));

  # Dockerfiles are sent without a build context; none of them COPY local files.
  # Prune filters cannot match tags, so the docker-prune alias skips this label.
  buildMcpImages = pkgs.writeShellScript "build-mcp-images" ''
    status=0
    ${lib.concatMapStrings (image: ''
      echo "Building ${image.name}"
      ${pkgs.docker}/bin/docker build --label local.keep=true \
        --tag ${lib.escapeShellArg "${image.name}:local"} - \
        < ${image.file} || status=1
    '') mcpDockerfiles}
    exit $status
  '';
in
{
  # Nix builds have no Docker daemon, and Podman's images are invisible to Docker.
  systemd.user.services.docker-mcp-builder = {
    Unit = {
      Description = "Build local MCP server images";
      Requires = [ "docker.service" ];
      After = [ "docker.service" ];
      # The script's store path changes with any Dockerfile, rerunning the build.
      X-Restart-Triggers = [ "${buildMcpImages}" ];
    };
    Service = {
      Type = "oneshot";
      RemainAfterExit = true;
      Environment = [ "DOCKER_HOST=unix://%t/docker.sock" ];
      ExecStart = buildMcpImages;
      TimeoutStartSec = "15min";
    };
    Install.WantedBy = [ "default.target" ];
  };
}
