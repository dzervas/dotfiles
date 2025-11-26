{ lib
, buildNpmPackage
, fetchurl
}:

buildNpmPackage rec {
  pname = "codex";
  version = "0.63.0";

  src = fetchurl {
    url = "https://registry.npmjs.org/@openai/codex/-/codex-${version}.tgz";
    hash = "sha256-CXVGj6hEyc/AGdOgq3/w2zrZR5thuEXrVNNy/rE3Z+E=";
  };

  # Package ships all runtime files; no dependencies to fetch.
  npmDepsHash = "sha256-pQpattmS9VmO3ZIQUFn66az8GSmB4IvYhTTCFn6SUmo=";
  forceEmptyCache = true;

  dontNpmBuild = true;

  meta = with lib; {
    description = "OpenAI Codex CLI (packaged from @openai/codex)";
    homepage = "https://github.com/openai/codex";
    license = licenses.asl20;
    mainProgram = "codex";
    platforms = platforms.unix;
  };
}
