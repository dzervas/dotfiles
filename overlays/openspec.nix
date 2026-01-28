# nix-update:openspec
{
  lib,
  stdenv,
  fetchFromGitHub,
  fetchPnpmDeps,
  nodejs_22,
  pnpm,
  pnpmConfigHook,
  makeWrapper,
}:
stdenv.mkDerivation rec {
  pname = "openspec";
  version = "1.0.2";

  src = fetchFromGitHub {
    owner = "Fission-AI";
    repo = "OpenSpec";
    rev = "v${version}";
    hash = "sha256-InoHfLQHItOFceWB0nReqxH8Az/QlBVh8T1FDIdjavs=";
  };

  nativeBuildInputs = [
    nodejs_22
    pnpm
    pnpmConfigHook
    makeWrapper
  ];

  # Download dependencies up-front for offline, reproducible installs.
  pnpmDeps = fetchPnpmDeps {
    inherit pname version src;
    fetcherVersion = 2;
    hash = "sha256-Tj2vGOTm1Uk1iQUu1NRbMf2S02TUm/bs7Gj1l/TIGXY=";
  };

  buildPhase = ''
    runHook preBuild
    pnpm install --offline --frozen-lockfile
    pnpm run build
    runHook postBuild
  '';

  installPhase = ''
    runHook preInstall
    mkdir -p $out/bin
    cp -r dist bin package.json $out/
    cp -r node_modules $out/
    # Wrapper ensures we use the bundled Node version and can resolve deps.
    makeWrapper ${nodejs_22}/bin/node $out/bin/openspec \
      --set NODE_PATH $out/node_modules \
      --add-flags $out/bin/openspec.js
    runHook postInstall
  '';

  # Vitest isn't needed for the packaged CLI.
  doCheck = false;

  meta = with lib; {
    description = "AI-native CLI for spec-driven development";
    homepage = "https://github.com/Fission-AI/OpenSpec";
    license = licenses.mit;
    mainProgram = "openspec";
    platforms = platforms.unix;
  };
}
