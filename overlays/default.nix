# To build a specific package:
# nix-build -E 'with import <nixpkgs> {}; callPackage ./overlays/<file> {}'
# or
# nix build --impure --expr 'let pkgs = import <nixpkgs> {}; in pkgs.callPackage /home/dzervas/Lab/dotfiles/overlays/<file> {}'
# To find the nix store path of a package:
# nix path-info --impure --expr 'let pkgs = import <nixpkgs> {}; in pkgs.callPackage /home/dzervas/Lab/dotfiles/overlays/<file> {}'
# To remove the build output of a nix store path:
# nix-store --delete /nix/store/hash
final: prev: {
  buspirate5-firmware = prev.callPackage ./buspirate5-firmware.nix {};
  claude-chrome = prev.callPackage ./claude-chrome.nix {};
  compact-nix = prev.callPackage ./compact-nix.nix {};
  # Version updates also require regenerating overlays/pi-dashboard/package-lock.json.
  pi-dashboard = prev.callPackage ./pi-dashboard.nix {};
  # nix-update:cursortab-nvim --subpackage server
  cursortab-nvim = prev.callPackage ./cursortab-nvim.nix {};
  # nix-update:codex-latest --custom-dep platformSrc
  codex-latest = prev.callPackage ./codex.nix {};
  # nix-update:anytype-cli
  anytype-cli = prev.callPackage ./anytype-cli.nix {};
  # nix-update :n8n-cli --version-regex 'n8n@(2\.\d+\.\d+)'
  n8n-cli = prev.callPackage ./n8n-cli.nix {};
  # nix-update:docker-mcp
  docker-mcp = prev.callPackage ./docker-mcp.nix {};
  # nix-update:docker-secrets-engine
  docker-secrets-engine = prev.callPackage ./docker-secrets-engine.nix {};

  # nix-update:brave
  # TODO: This uses the nightly releases
  # https://github.com/Mic92/nix-update/issues/639
  brave = prev.brave.overrideAttrs (
    finalAttrs: _oldAttrs: {
      version = "1.100.24";
      src = final.fetchurl {
        url = "https://github.com/brave/brave-browser/releases/download/v${finalAttrs.version}/brave-browser_${finalAttrs.version}_amd64.deb";
        sha256 = "21d7ac36b64a408dc598bb6ec3db84b07b2cbca854d26b28055a2fb5b94a2e77";
      };
    }
  );

  # nix-update:atuin
  atuin = prev.atuin.overrideAttrs (
    finalAttrs: oldAttrs: {
      version = "18.24.2";

      src = final.fetchFromGitHub {
        owner = "atuinsh";
        repo = "atuin";
        tag = "v${finalAttrs.version}";
        hash = "sha256-b6Uj3cPAu731lhrN8fOv4d0CpehT3bv7IOBmkbYrqfI=";
      };

      cargoHash = "sha256-HkYI2+Yvjnw9pKeRsteyZeLhHHErTa1mvJL16NQVF3g=";

      cargoDeps = final.rustPlatform.fetchCargoVendor {
        inherit (finalAttrs) pname version src;
        hash = finalAttrs.cargoHash;
      };

      # This integration test requires a running PostgreSQL server.
      checkFlags = oldAttrs.checkFlags ++ [ "--skip=postgres_authenticates_with_the_password_file" ];
    }
  );

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
      version = "1.4.0";

      src = final.fetchFromGitHub {
        owner = "earendil-works";
        repo = "pi";
        tag = "v${finalAttrs.version}";
        hash = "sha256-N9NOpiiZTbOMDMV+CxvJAgtLjJJ1/8NJBGS0cFHkhsc=";
      };

      npmDepsHash = "sha256-aBzVz78IxZQlzPYC72Ufa2YFtkow6nZR24YBYZrv9W0=";

      npmDeps = final.fetchNpmDeps {
        inherit (finalAttrs) src;
        name = "${finalAttrs.pname}-${finalAttrs.version}-npm-deps";
        hash = finalAttrs.npmDepsHash;
      };

      modelData = final.fetchurl {
        url = "https://registry.npmjs.org/@earendil-works/pi-ai/-/pi-ai-${finalAttrs.version}.tgz";
        hash = "sha256-tA4rqLtvwzKQj4uW6DfcLR/ftF65zTgvWu0RFGKYHjw=";
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
      #             @earendil-works/pi-codemode:packages/codemode/declarations \
      #             @earendil-works/pi-codemode:packages/codemode/portable; do
      #     IFS=: read -r pkg src <<< "$ws"
      #     rm "$nm/$pkg"
      #     cp -r "$src" "$nm/$pkg"
      #   done
      # ''
      # + _prevAttrs.postInstall;

      # Required when upstream drops a workspace that nixpkgs' postInstall still copies:
      # 1.2.0 removed packages/client and packages/protocol, and the inherited loop
      # fails on `rm` of their missing symlinks. Drop once nixpkgs packages >= 1.2.0.
      postInstall = ''
        local nm="$out/lib/node_modules/pi-monorepo/node_modules"

        for ws in @earendil-works/chord:packages/chord \
                  @earendil-works/pi-ai:packages/ai \
                  @earendil-works/pi-agent-core:packages/agent \
                  @earendil-works/pi-codemode:packages/codemode \
                  @earendil-works/pi-mcp:packages/mcp \
                  @earendil-works/pi-telemetry:packages/telemetry \
                  @earendil-works/pi-tui:packages/tui; do
          IFS=: read -r pkg src <<< "$ws"
          rm "$nm/$pkg"
          cp -r "$src" "$nm/$pkg"
        done

        find "$nm" -type l -lname '*/packages/*' -delete
        find "$nm/.bin" -xtype l -delete
      '';
    }
  );
}
