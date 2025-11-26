{ lib
, buildNpmPackage
, fetchurl
}:

buildNpmPackage rec {
  pname = "openspec";
  version = "0.16.0";

  src = fetchurl {
    url = "https://registry.npmjs.org/@fission-ai/openspec/-/openspec-${version}.tgz";
    hash = "sha256-1YcXo8sNWamrCQld33PE/dyZr/vz0dZRWp8dkDjnzWA=";
  };

  # Generate the lockfile inside the build so npmDepsHash stays stable without vendoring one.
  postPatch = ''
    npm install --package-lock-only --ignore-scripts
  '';

  npmDepsHash = "sha256-1YcXo8sNWamrCQld33PE/dyZr/vz0dZRWp8dkDjnzWA=";

  # The tarball ships pre-built JS in dist/, so skip running upstream build.
  dontNpmBuild = true;

  meta = with lib; {
    description = "AI-native CLI for spec-driven development";
    homepage = "https://github.com/Fission-AI/OpenSpec";
    license = licenses.mit;
    mainProgram = "openspec";
    platforms = platforms.unix;
  };
}
