{ lib
, stdenvNoCC
, fetchurl
, nodejs
}:
stdenvNoCC.mkDerivation rec {
  pname = "codex";
  version = "0.116.0";

  src = fetchurl {
    url = "https://registry.npmjs.org/@openai/codex/-/codex-${version}.tgz";
    hash = "sha256-8fgQDXrNwRl7gQ7yq1RD8XnPK3tHiIXogiWJP+2jw0c=";
  };

  platformSrc = fetchurl {
    url = "https://registry.npmjs.org/@openai/codex/-/codex-${version}-linux-x64.tgz";
    hash = "sha256-t9PmgdvnSDFVkvCgrpzhhvLlnPftqdfGd1KQ8JROWlE=";
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
