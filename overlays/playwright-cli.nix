{
  lib,
  buildNpmPackage,
  npmHooks,
  fetchNpmDeps,
  fetchFromGitHub,
  nodejs,
}:
buildNpmPackage (_finalAttrs: rec {
  pname = "playwright-cli";
  version = "0.1.6";

  src = fetchFromGitHub {
    owner = "microsoft";
    repo = "playwright-cli";
    tag = "v${version}";
    hash = "sha256-NtYGVWOiqYNoyRQ/Rt4kSBcuGJn6Yb8yxa0X41sDyYU=";
  };

  nativeBuildInputs = [
    nodejs
    npmHooks.npmConfigHook
  ];

  npmDeps = fetchNpmDeps {
    inherit src;
    hash = "sha256-bvtwt04ECC/NvfWWuBdDZ+8PFlTtOtRquJHS7vie1m8=";
  };
  # npmDeps = importNpmLock { npmRoot = src; };
  # npmConfigHook = importNpmLock.npmConfigHook;

  dontNpmBuild = true;

  installPhase = ''
    runHook preInstall

    mkdir -p "$out/bin" "$out/lib"
    cp -rv *.js $out/lib
    cp -rv *.json $out/lib

    cat >> $out/bin/${pname}  <<EOF
    #!/bin/sh
    ${lib.getExe nodejs} $out/lib/playwright-cli.js
    EOF
    chmod +x $out/bin/${pname}

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
