opencode: final: _prev: let
  inherit (final) lib;
  upstream = opencode.packages.${final.stdenv.hostPlatform.system};
  # Upstream Nix uses "prod", which writes service-prod.json while Desktop
  # discovers service.json. "latest" is the CLI's stable release channel;
  # Electron maps it to "prod" itself, so the native app identity stays the same.
  cli = upstream.opencode.overrideAttrs (oldAttrs: {
    env = oldAttrs.env // { OPENCODE_CHANNEL = "latest"; };
  });
  desktop = upstream.opencode-desktop.override { opencode = cli; };
  # Keep relative imports and prompt assets intact, reusing the Pi backend
  # without bringing its extension loader, UI, or node_modules into OpenCode.
  memory = final.runCommand "opencode-learned-memory" {} ''
    mkdir -p "$out/overlays/opencode-desktop/"{tests,extension} "$out/pi/extensions/"{memory,lib}
    cp ${./extension/server.js} "$out/overlays/opencode-desktop/extension/server.js"
    cp -R ${./memory} "$out/overlays/opencode-desktop/memory"
    cp ${./tests}/*.test.ts "$out/overlays/opencode-desktop/tests/"
    cp ${../../pi/extensions/memory/atuin.ts} "$out/pi/extensions/memory/atuin.ts"
    cp ${../../pi/extensions/memory/store.ts} "$out/pi/extensions/memory/store.ts"
    cp ${../../pi/extensions/lib/prompts.ts} "$out/pi/extensions/lib/prompts.ts"
    cp ${../../pi/extensions/prompts.md} "$out/pi/extensions/prompts.md"
    cp ${final.writeText "opencode-memory-server.ts" ''
      // A local plugin package needs a server entrypoint; shared modules retain their own relative imports.
      export { default } from "./overlays/opencode-desktop/memory/index.ts";
    ''} "$out/server.ts"
    cp ${final.writeText "opencode-memory-package.json" (builtins.toJSON {
      name = "dotfiles-learned-memory";
      type = "module";
      main = "./server.ts";
    })} "$out/package.json"
  '';
  sandboxConfig = final.writeText "opencode-sandbox.json" (builtins.toJSON {
    plugins = [ "${memory}" ];
    # Native discovery owns file loading, watches and change announcements.
    instructions = [ "AGENTS.local.md" ".pi/AGENTS.md" ];
  });
  launcher = final.writeScript "opencode-sandbox" (
    lib.replaceStrings
      [
        "@fish@"
        "@coreutils@"
        "@git@"
        "@node@"
        "@namespace@"
        "@sandboxConfig@"
      ]
      [
        "${final.fish}"
        "${final.coreutils}"
        "${final.git}"
        "${final.nodejs}"
        "${memory}/overlays/opencode-desktop/memory/namespace.ts"
        "${sandboxConfig}"
      ]
      (builtins.readFile ./sandbox.fish)
  );
in {
  opencode = cli;
  opencode-desktop = desktop.overrideAttrs (oldAttrs: {
    postPatch = (oldAttrs.postPatch or "") + ''
      ${lib.getExe final.nodejs} ${./inject.js} . ${./extension} ${launcher} ${cli}

      # Nix, not electron-updater, owns this locally extended application.
      substituteInPlace packages/gui-extensions/src/updater/main.ts \
        --replace-fail 'const enabled = build.packaged && build.channel !== "dev"' 'const enabled = false'
    '';

    doCheck = true;
    checkPhase = ''
      runHook preCheck
      OPENCODE_TEST_CLI=${lib.getExe cli} FISH=${lib.getExe final.fish} \
        ${lib.getExe final.nodejs} --experimental-vm-modules --test ${./.}/tests/*.test.js
      OPENCODE_TEST_CLI=${lib.getExe cli} OPENCODE_TEST_MEMORY=${memory} OPENCODE_TEST_ATUIN=${lib.getExe final.atuin} OPENCODE_TEST_GIT=${lib.getExe final.git} \
        ${lib.getExe final.nodejs} --experimental-transform-types --experimental-vm-modules \
        --test ${memory}/overlays/opencode-desktop/tests/*.test.ts
      ${lib.getExe final.fish} --no-config --no-execute ${./sandbox.fish}
      runHook postCheck
    '';

    meta = oldAttrs.meta // {
      # The application is cross-platform; our bubblewrap integration is not.
      platforms = lib.intersectLists lib.platforms.linux oldAttrs.meta.platforms;
    };
  });
}
