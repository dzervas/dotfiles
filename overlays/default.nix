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
  pi-durable = prev.callPackage ./pi-durable.nix {
    inherit (final) pi-coding-agent-latest;
  };
  # nix-update:cursortab-nvim --subpackage server
  cursortab-nvim = prev.callPackage ./cursortab-nvim.nix { };
  # nix-update:codex-latest --custom-dep platformSrc
  codex-latest = prev.callPackage ./codex.nix { };
  # nix-update:anytype-cli
  anytype-cli = prev.callPackage ./anytype-cli.nix { };
  # nix-update :n8n-cli --version-regex 'n8n@(2\.\d+\.\d+)'
  n8n-cli = prev.callPackage ./n8n-cli.nix { };
  # nix-update:docker-mcp
  docker-mcp = prev.callPackage ./docker-mcp.nix { };
  # nix-update:docker-secrets-engine
  docker-secrets-engine = prev.callPackage ./docker-secrets-engine.nix { };

  # nix-update:brave
  # TODO: This uses the nightly releases
  # https://github.com/Mic92/nix-update/issues/639
  brave = prev.brave.overrideAttrs (finalAttrs: _oldAttrs: {
    version = "1.99.9";
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
  pi-coding-agent-latest = prev.pi-coding-agent.overrideAttrs (
    finalAttrs: _prevAttrs: {
      version = "1.0.0";

      src = final.fetchFromGitHub {
        owner = "earendil-works";
        repo = "pi";
        tag = "v${finalAttrs.version}";
        hash = "sha256-CGznIVHXG6gr2F8vzHcR/v4P9xJgZHeMTt/CJ/kB78o=";
      };

      npmDepsHash = "sha256-ndEvWdB6sa5nNNtabk2OMZKUFG9x3op185deZHxFnXk=";

      npmDeps = final.fetchNpmDeps {
        inherit (finalAttrs) src;
        name = "${finalAttrs.pname}-${finalAttrs.version}-npm-deps";
        hash = finalAttrs.npmDepsHash;
      };

      modelData = final.fetchurl {
        url = "https://registry.npmjs.org/@earendil-works/pi-ai/-/pi-ai-${finalAttrs.version}.tgz";
        hash = "sha256-85uZwpuFmPF1sQhA5dKoGYPnwM5crk19+DoQB0R9LCs=";
      };

      # Use upstream's offline build order and TypeScript compiler.
      buildPhase = ''
        runHook preBuild

        npm run build:offline

        runHook postBuild
      '';

      # Required when a new package is introduced in upstream vs nix packaged
      # If no longer required comment it out, don't remove it, might be needed later
      # Preserve the new runtime workspaces before the inherited symlink cleanup.
      # postInstall = ''
      #   local nm="$out/lib/node_modules/pi-monorepo/node_modules"
      #   for ws in @earendil-works/pi-codemode:packages/codemode \
      #             @earendil-works/pi-mcp:packages/mcp; do
      #     IFS=: read -r pkg src <<< "$ws"
      #     rm "$nm/$pkg"
      #     cp -r "$src" "$nm/$pkg"
      #   done
      # '' + _prevAttrs.postInstall;
    }
  );
}
