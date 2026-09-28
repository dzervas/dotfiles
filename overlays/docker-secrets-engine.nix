{
  lib,
  stdenvNoCC,
  fetchurl,
}:
stdenvNoCC.mkDerivation rec {
  pname = "docker-secrets-engine";
  version = "0.10.0";

  src = fetchurl {
    url = "https://github.com/docker/secrets-engine/releases/download/v${version}/secrets-engine-linux_amd64.tar.gz";
    hash = "sha256-cKnAROC0t+6PZojMrtfHKRtZ2kNiXfKDZ/eVD5L2ft0=";
  };

  sourceRoot = ".";

  installPhase = ''
    runHook preInstall

    install -Dm755 secrets-engine "$out/bin/secrets-engine"
    ln -s secrets-engine "$out/bin/docker-pass"
    mkdir -p "$out/libexec/docker/cli-plugins"
    ln -s ../../../bin/secrets-engine "$out/libexec/docker/cli-plugins/docker-pass"

    runHook postInstall
  '';

  meta = with lib; {
    description = "Docker Secrets Engine daemon and docker pass CLI plugin";
    homepage = "https://github.com/docker/secrets-engine";
    license = licenses.asl20;
    mainProgram = "secrets-engine";
    platforms = [ "x86_64-linux" ];
  };
}
