{
  lib,
  stdenv,
  buildNpmPackage,
  importNpmLock,
  nodejs,
  makeWrapper,
  autoPatchelfHook,
  libxcb,
}:
buildNpmPackage {
  pname = "pi-dashboard";
  version = "0.9.0";

  # The published npm package includes the web build, unlike the source checkout.
  # Update package.json and regenerate package-lock.json together when bumping.
  src = ./pi-dashboard;
  npmDeps = importNpmLock {
    npmRoot = ./pi-dashboard;
    packageLock = let
      lock = lib.importJSON ./pi-dashboard/package-lock.json;
    in lib.recursiveUpdate lock {
      # importNpmLock rewrites resolved URLs, but not URL dependency constraints.
      # Use the pinned version so offline npm selects the local xlsx tarball.
      packages."node_modules/@blackbelt-technology/pi-dashboard-server".dependencies.xlsx =
        lock.packages."node_modules/xlsx".version;
    };
  };
  inherit (importNpmLock) npmConfigHook;
  dontNpmBuild = true;

  nativeBuildInputs = [
    makeWrapper
    autoPatchelfHook
  ];
  buildInputs = [
    stdenv.cc.cc.lib
    libxcb
  ];

  # npm also ships unused musl variants alongside the glibc native addons.
  autoPatchelfIgnoreMissingDeps = [
    "libc.musl-*.so.1"
    "libc.so"
  ];

  installPhase = ''
    runHook preInstall

    test -f node_modules/@blackbelt-technology/pi-dashboard-web/dist/index.html
    mkdir -p "$out/lib/pi-dashboard" "$out/bin"
    cp -r node_modules "$out/lib/pi-dashboard/"

    makeWrapper "${lib.getExe nodejs}" "$out/bin/pi-dashboard" \
      --add-flags "$out/lib/pi-dashboard/node_modules/@blackbelt-technology/pi-agent-dashboard/packages/server/bin/pi-dashboard.mjs" \
      --prefix PATH : "${lib.makeBinPath [ nodejs ]}"

    runHook postInstall
  '';

  meta = with lib; {
    description = "Web dashboard for monitoring and interacting with Pi agent sessions";
    homepage = "https://github.com/BlackBeltTechnology/pi-agent-dashboard";
    license = licenses.mit;
    mainProgram = "pi-dashboard";
    platforms = [
      "x86_64-linux"
      "aarch64-linux"
    ];
  };
}
