{
  lib,
  buildNpmPackage,
  makeWrapper,
  nodejs_22,
  pi-coding-agent-latest,
  bash,
  fd,
  ripgrep,
}:
buildNpmPackage {
  pname = "pi-durable";
  # Share Pi's source pin and offline cache so both packages upgrade together.
  inherit (pi-coding-agent-latest)
    version
    src
    npmDeps
    npmDepsHash
    modelData
    ;
  nodejs = nodejs_22;

  npmRebuildFlags = [ "--ignore-scripts" ];
  nativeBuildInputs = [ makeWrapper ];

  preConfigure = ''
    mkdir -p packages/ai/src/providers/data
    tar --extract --gzip --file=$modelData \
      --directory=packages/ai/src/providers/data \
      --strip-components=4 \
      package/dist/providers/data
  '';

  buildPhase = ''
    runHook preBuild

    # The demo runs from source; compile the SDK and its public dependencies.
    for workspace in chord telemetry ai durable; do
      node_modules/.bin/tsc -p "packages/$workspace/tsconfig.build.json"
    done

    runHook postBuild
  '';

  installPhase = ''
    runHook preInstall

    npm prune --omit=dev --ignore-scripts --no-save --offline
    runtime="$out/lib/pi-durable"
    mkdir -p "$runtime"
    # Upstream's source resolver needs this monorepo layout and tsconfig aliases.
    cp -r packages node_modules package.json tsconfig.json tsconfig.base.json "$runtime/"

    makeWrapper ${nodejs_22}/bin/node "$out/bin/pi-durable" \
      --add-flags "--import $runtime/packages/coding-agent/src/experimental/source-resolver.ts" \
      --add-flags "$runtime/packages/coding-agent/src/experimental/durable/main.ts" \
      --prefix PATH : ${lib.makeBinPath [ bash fd ripgrep ]} \
      --set-default PI_SKIP_VERSION_CHECK 1 \
      --set-default PI_TELEMETRY 0

    runHook postInstall
  '';

  doInstallCheck = true;
  installCheckPhase = ''
    runHook preInstallCheck

    ${nodejs_22}/bin/node \
      --import "$out/lib/pi-durable/packages/coding-agent/src/experimental/source-resolver.ts" \
      --input-type=module <<EOF_CHECK
    import "$out/lib/pi-durable/packages/coding-agent/src/experimental/durable/runtime.ts";
    import "$out/lib/pi-durable/packages/coding-agent/src/experimental/durable/tui.ts";
    import { DatabaseSync } from "node:sqlite";
    const db = new DatabaseSync(":memory:");
    if (db.prepare("SELECT 1 AS value").get().value !== 1) throw new Error("SQLite smoke test failed");
    db.close();
    EOF_CHECK

    ${nodejs_22}/bin/node --input-type=module <<EOF_CHECK
    import { defineExtension } from "$out/lib/pi-durable/packages/durable/dist/index.js";
    if (defineExtension({ name: "packaging-check" }).name !== "packaging-check") {
      throw new Error("Compiled SDK smoke test failed");
    }
    EOF_CHECK

    runHook postInstallCheck
  '';

  meta = with lib; {
    description = "Experimental Pi Durable coding-agent TUI and durable harness SDK";
    homepage = "https://github.com/earendil-works/pi/tree/main/packages/durable";
    license = licenses.mit;
    mainProgram = "pi-durable";
    platforms = platforms.linux;
  };
}
