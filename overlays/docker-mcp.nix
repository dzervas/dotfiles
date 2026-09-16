{
  stdenv,
  fetchurl,
}:
stdenv.mkDerivation {
  pname = "docker-mcp";
  version = "0.43.3";

  src = fetchurl {
    url = "...release asset...";
    hash = "...";
  };

  dontUnpack = true;

  installPhase = ''
    mkdir -p $out/libexec/docker/cli-plugins
    cp $src $out/libexec/docker/cli-plugins/docker-mcp
    chmod +x $out/libexec/docker/cli-plugins/docker-mcp
  '';
}
