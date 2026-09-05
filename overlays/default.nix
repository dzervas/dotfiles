# To build a specific package:
# nix-build -E 'with import <nixpkgs> {}; callPackage ./overlays/<file> {}'
# or
# nix build --impure --expr 'let pkgs = import <nixpkgs> {}; in pkgs.callPackage /home/dzervas/Lab/dotfiles/overlays/<file> {}'
# To find the nix store path of a package:
# nix path-info --impure --expr 'let pkgs = import <nixpkgs> {}; in pkgs.callPackage /home/dzervas/Lab/dotfiles/overlays/<file> {}'
# To remove the build output of a nix store path:
# nix-store --delete /nix/store/hash
final: prev: {
  buspirate5-firmware = prev.callPackage ./buspirate5-firmware.nix { };
  claude-chrome = prev.callPackage ./claude-chrome.nix { };
  # nix-update:cursortab-nvim --subpackage server
  cursortab-nvim = prev.callPackage ./cursortab-nvim.nix { };
  # nix-update:codex-latest --custom-dep platformSrc
  codex-latest = prev.callPackage ./codex.nix { };
  # nix-update:anytype-cli
  anytype-cli = prev.callPackage ./anytype-cli.nix { };
  # nix-update :n8n-cli --version-regex 'n8n@(2\.\d+\.\d+)'
  n8n-cli = prev.callPackage ./n8n-cli.nix { };

  # nix-update:brave
  # TODO: This uses the nightly releases
  # https://github.com/Mic92/nix-update/issues/639
  brave = prev.brave.overrideAttrs (finalAttrs: _oldAttrs: {
    version = "1.94.121";
    src = final.fetchurl {
      url = "https://github.com/brave/brave-browser/releases/download/v${finalAttrs.version}/brave-browser_${finalAttrs.version}_amd64.deb";
      sha256 = "21d7ac36b64a408dc598bb6ec3db84b07b2cbca854d26b28055a2fb5b94a2e77";
    };
  });

  _1password-gui = prev._1password-gui.overrideAttrs (oldAttrs: {
     postInstall = (oldAttrs.postInstall or "") + ''
       patchelf --set-interpreter \
         "$(patchelf --print-interpreter "$out/share/1password/op-ssh-sign")" \
         "$out/share/1password/1password-mcp"
       patchelf --set-rpath \
         "$(patchelf --print-rpath "$out/share/1password/op-ssh-sign")" \
         "$out/share/1password/1password-mcp"

       ln -s "$out/share/1password/1password-mcp" "$out/bin/1password-mcp"
     '';
   });

  # nix-update:pi-coding-agent-latest --custom-dep modelData
  # Broken:
  pi-coding-agent-latest = prev.pi-coding-agent.overrideAttrs (
    finalAttrs: prevAttrs: {
      version = "0.85.0";

      src = final.fetchFromGitHub {
        owner = "earendil-works";
        repo = "pi";
        tag = "v${finalAttrs.version}";
        hash = "sha256-gznGlneVCx3htxRiJq0/futm4qLR9Bzfv3UwP3ES9v0=";
      };

      npmDepsHash = "sha256-K/KiukwTHwu4HE8hUu7ur3bxggwfO0WL+QDI0FtxP3I=";

      npmDeps = final.fetchNpmDeps {
        inherit (finalAttrs) src;
        name = "${finalAttrs.pname}-${finalAttrs.version}-npm-deps";
        hash = finalAttrs.npmDepsHash;
      };

      modelData = final.fetchurl {
        url = "https://registry.npmjs.org/@earendil-works/pi-ai/-/pi-ai-${finalAttrs.version}.tgz";
        hash = "sha256-RhiL2stVWgdGagER85Y/IJMqFhmeTWz7jUSn/l/G40I=";
      };

      # Required when a new package is introduced in upstream vs nix packaged
      # If no longer required comment it out, don't remove it, might be needed later
      buildPhase = ''
        runHook preBuild

        npx tsgo -p packages/tui/tsconfig.build.json
        npx tsgo -p packages/telemetry/tsconfig.build.json
        npx tsgo -p packages/ai/tsconfig.build.json
        npx tsgo -p packages/chord/tsconfig.build.json
        npx tsgo -p packages/agent/tsconfig.build.json
        npx tsgo -p packages/protocol/tsconfig.build.json
        npx tsgo -p packages/client/tsconfig.build.json
        npx tsgo -p packages/server/tsconfig.build.json
        npm run build --workspace=packages/coding-agent

        runHook postBuild
      '';

      # If the above required new packages, this needs to patch them
      postInstall = ''
        local nm="$out/lib/node_modules/pi-monorepo/node_modules"
        for ws in @earendil-works/chord:packages/chord \
                  @earendil-works/pi-server:packages/server; do
          IFS=: read -r pkg src <<< "$ws"
          rm "$nm/$pkg"
          cp -r "$src" "$nm/$pkg"
        done
      '' + prevAttrs.postInstall;
    }
  );
}
