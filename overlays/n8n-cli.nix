{
  lib,
  stdenv,
  fetchFromGitHub,
  nodejs,
  makeWrapper,
  pnpm,
  fetchPnpmDeps,
  pnpmConfigHook,
}:
stdenv.mkDerivation (finalAttrs: rec {
  pname = "n8n-cli";
  version = "2.14.2";

  src = fetchFromGitHub {
    owner = "n8n-io";
    repo = "n8n";
    tag = "v${version}";
    hash = "sha256-tbSaID0kajqEoipDgwk4kxEbY4AXTWiaKO/BfyzC0e8=";
  };

  pnpmWorkspaces = [ "@n8n/cli..." ];

  pnpmDeps = fetchPnpmDeps {
    inherit (finalAttrs)
      pname
      version
      src
      pnpmWorkspaces
      ;
    inherit pnpm;
    fetcherVersion = 1;
    hash = "sha256-714fwBjrMlOG7SFzitb+sXZZ9tkzK5jFlilMf2pRBC4=";
  };

  nativeBuildInputs = [
    nodejs
    makeWrapper
    pnpmConfigHook
    pnpm
  ];

  buildPhase = ''
    runHook preBuild
    pnpm --filter @n8n/cli build
    runHook postBuild
  '';

  installPhase = ''
    runHook preInstall

    local -r packageOut="$out/lib/node_modules/@n8n/cli"

    mkdir -p "$out/lib/node_modules/@n8n" "$out/bin"
    cp -r node_modules "$out/lib/"
    cp -r packages/@n8n/cli "$packageOut"

    rm -f "$out/lib/node_modules/@n8n/eslint-config"
    rm -f "$packageOut/node_modules/@n8n/typescript-config"
    rm -f "$packageOut/node_modules/@n8n/vitest-config"

    makeWrapper "${lib.getExe nodejs}" "$out/bin/n8n-cli" \
      --add-flags "$packageOut/bin/n8n-cli.mjs"

    runHook postInstall
  '';

  meta = with lib; {
    description = "Command-line client for n8n";
    homepage = "https://github.com/n8n-io/n8n";
    license = licenses.unfree;
    mainProgram = "n8n-cli";
    platforms = nodejs.meta.platforms;
  };
})
