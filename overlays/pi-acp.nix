{
  lib,
  buildNpmPackage,
  fetchFromGitHub,
  ...
}:
buildNpmPackage rec {
  pname = "pi-acp";
  version = "0.0.34";

  src = fetchFromGitHub {
    owner = "svkozak";
    repo = "pi-acp";
    rev = "04d0a15d6bb42bb65cce5c9caedcdcb2cdcb6905";
    hash = "sha256-V9+WNpJQK2a/S3e5KVXfiK1bhQlXrUKIaowhOZa6BIg=";
  };

  patches = [
    ../pi/acp/adapter.patch
    ../pi/acp/nix-test-launchers.patch # Generated scripts bypass patchShebangs.
  ];
  npmDepsHash = "sha256-BvLNtFfp1cMVjzWcMRSdhTqiJrTfbFoUbWkkPW9200o=";

  doCheck = true;
  checkPhase = ''
    runHook preCheck
    npm run typecheck
    npm test
    runHook postCheck
  '';

  meta = with lib; {
    description = "Sandbox-launcher compatible Pi ACP adapter with native forms and plans";
    homepage = "https://github.com/svkozak/pi-acp";
    license = licenses.mit;
    mainProgram = "pi-acp";
    platforms = platforms.unix;
  };
}
