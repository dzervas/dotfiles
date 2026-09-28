{
  lib,
  stdenvNoCC,
  fetchurl,
}:
stdenvNoCC.mkDerivation rec {
  pname = "docker-mcp";
  version = "0.44.1";

  src = fetchurl {
    url = "https://github.com/docker/mcp-gateway/releases/download/v${version}/docker-mcp-linux-amd64.tar.gz";
    hash = "sha256-jN0SG4fhr+EeZt+onvO9BUM8A4nPJzmd5w/T7wxkNOk=";
  };

  sourceRoot = ".";

  installPhase = ''
    runHook preInstall

    install -Dm755 docker-mcp "$out/libexec/docker/cli-plugins/docker-mcp"

    runHook postInstall
  '';

  meta = with lib; {
    description = "Docker MCP Gateway CLI plugin";
    homepage = "https://github.com/docker/mcp-gateway";
    license = licenses.asl20;
    mainProgram = "docker-mcp";
    platforms = [ "x86_64-linux" ];
  };
}
