{ lib
, stdenvNoCC
, fetchurl
, nodejs
}:
stdenvNoCC.mkDerivation rec {
  pname = "codex";
  version = "0.104.0";

  src = fetchurl {
    url = "https://registry.npmjs.org/@openai/codex/-/codex-${version}.tgz";
    hash = "sha256-Dn5tpyhWsQVLCm1n5I/ut1DCvNcKGZxk+BLrk/76qiI=";
  };

  platformSrc = fetchurl {
    url = "https://registry.npmjs.org/@openai/codex/-/codex-${version}-linux-x64.tgz";
    hash = "sha256-eQjShAeqYq6tmY15Kek1In55pEJdymaAKZ3im6+B3gs=";
  };

  nativeBuildInputs = [ nodejs ];
  propagatedBuildInputs = [ nodejs ];

  sourceRoot = "package";

  installPhase = ''
    runHook preInstall

    mkdir -p "$out/lib/codex" "$out/bin"

    cp -r bin "$out/lib/codex/"

    mkdir -p platform
    tar -xzf "$platformSrc" -C platform
    cp -r platform/package/vendor "$out/lib/codex/"

    patchShebangs "$out/lib/codex/bin"
    ln -s "$out/lib/codex/bin/codex.js" "$out/bin/codex"

    runHook postInstall
  '';

  meta = with lib; {
    description = "OpenAI Codex CLI (packaged from @openai/codex)";
    homepage = "https://github.com/openai/codex";
    license = licenses.asl20;
    mainProgram = "codex";
    platforms = platforms.unix;
  };
}
