{
  stdenv,
  fetchurl,
}:
stdenv.mkDerivation rec {
  pname = "anytype-cli";
  version = "0.3.2";
  src = fetchurl {
    url = "https://github.com/anyproto/anytype-cli/releases/download/v${version}/anytype-cli-v${version}-linux-amd64.tar.gz";
    sha256 = "sha256-InauiWT7AWFuG3pLXZFmWybuEq4a8Aa8Uprtf5TIHpA=";
  };

  dontUnpack = true;

  installPhase = ''
    mkdir -p $out/bin release
    tar -xzf $src -C release
    install -m 0755 release/anytype $out/bin/${pname}
  '';

  meta.mainProgram = pname;
}
