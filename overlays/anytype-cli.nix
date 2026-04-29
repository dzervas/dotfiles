{
  stdenv,
  fetchurl,
}:
stdenv.mkDerivation rec {
  pname = "anytype-cli";
  version = "0.2.3";
  src = fetchurl {
    url = "https://github.com/anyproto/anytype-cli/releases/download/v${version}/anytype-cli-v${version}-linux-amd64.tar.gz";
    sha256 = "sha256-0nrXvIsa6k3zpRp1evkU+GOcdg8R5Xuq45d+ahvE24c=";
  };

  dontUnpack = true;

  installPhase = ''
    mkdir -p $out/bin release
    tar -xzf $src -C release
    install -m 0755 release/anytype $out/bin/${pname}
  '';

  meta.mainProgram = pname;
}
