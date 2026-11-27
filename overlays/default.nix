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
  # Bubblewrapped; the real binary is only reachable via eglantine.unwrapped
  # nix-update:eglantine.unwrapped
  eglantine = final.callPackage ./eglantine.nix {};
  # Lichii's nvn-direct dev build in the same sandbox (`nix run .#eglantine-dev`). Its data dir is
  # lichii, not eden: pick "Link Old Directory" in the first-launch migration prompt to share eglantine's data.
  # Local-only source that the update app can't bump; update the rev by hand (update hint in eglantine-dev.nix).
  # Without env it runs Lichii's normal renderer. The NVN2 direct renderer is opt-in and still in
  # bring-up (may hang in-game); shaders come from Lichii's recompiler (EDEN_NX2_NVN_SHLIB, the lab's MKW
  # library bound read-only by the sandbox, is only for comparisons):
  #   EDEN_NX2_NVN_DIRECT=1 nix run .#eglantine-dev
  eglantine-dev = final.callPackage ./eglantine-dev.nix {};
  # Upstream's prebuilt PGO AppImage in the same sandbox and data dir, for comparing against eglantine.
  # nix-update:eglantine-appimage.unwrapped
  eglantine-appimage = final.callPackage ./eglantine-appimage.nix {};
  # Version updates also require regenerating overlays/pi-dashboard/package-lock.json.
  pi-dashboard = prev.callPackage ./pi-dashboard.nix {};
  # nix-update:cursortab-nvim --subpackage server
  cursortab-nvim = prev.callPackage ./cursortab-nvim.nix {};
  # nix-update:codex-latest --custom-dep platformSrc
  codex-latest = prev.callPackage ./codex.nix {};
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
      version = "1.102.45";
      src = final.fetchurl {
        url = "https://github.com/brave/brave-browser/releases/download/v${finalAttrs.version}/brave-browser_${finalAttrs.version}_amd64.deb";
        sha256 = "21d7ac36b64a408dc598bb6ec3db84b07b2cbca854d26b28055a2fb5b94a2e77";
      };
    }
  );

  # nix-update:xwin
  # docs/testing.md of Leonida: xwin 0.10.0 lays out Windows SDK 10.0.26100, older ones may not
  xwin = prev.xwin.overrideAttrs (
    finalAttrs: oldAttrs: {
      version = "0.10.0";

      src = final.fetchFromGitHub {
        owner = "Jake-Shadle";
        repo = "xwin";
        tag = finalAttrs.version;
        hash = "sha256-kUbRHrM88x3ezy0+GIpbGQfEROn16dSwPtobjdYauRM=";
      };

      cargoHash = "sha256-34v/YDT0Juwjv8EbwsOsmbp/Q89Z4c+BYxcA60X7Q3A=";

      cargoDeps = final.rustPlatform.fetchCargoVendor {
        inherit (finalAttrs) pname version src;
        hash = finalAttrs.cargoHash;
      };

      # New in 0.10.0, downloads the manifest like the ones nixpkgs already skips
      checkFlags = oldAttrs.checkFlags ++ [ "--skip=verify_aarch64_compiles" ];
    }
  );

  # nix-update:atuin
  atuin = prev.atuin.overrideAttrs (
    finalAttrs: oldAttrs: {
      version = "18.25.1";

      src = final.fetchFromGitHub {
        owner = "atuinsh";
        repo = "atuin";
        tag = "v${finalAttrs.version}";
        hash = "sha256-fZpe677ju8n3X4Csj7HJDPqcWEFyPE7FL0zVNpiI72g=";
      };

      cargoHash = "sha256-SZKFzRmrz+p2b74SoZgovBoAxPAtL4MjERcv8PTNh5s=";

      cargoDeps = final.rustPlatform.fetchCargoVendor {
        inherit (finalAttrs) pname version src;
        hash = finalAttrs.cargoHash;
      };

      checkFlags = oldAttrs.checkFlags ++ [
        # This integration test requires a running PostgreSQL server.
        "--skip=postgres_authenticates_with_the_password_file"
        # Hardcodes /bin/bash, which the build sandbox lacks (the /bin/sh cases still run)
        "--skip=a_shell_without_a_terminal_runs_outside_the_proxy::shell_2____bin_bash__"
        # Its shim runs `sleep` from /usr/bin:/bin, which the build sandbox lacks, then checks with `ps`
        "--skip=a_shim_that_hangs_is_killed_with_its_children"
      ];

      # The stats tests use named time zones; the build sandbox has no /usr/share/zoneinfo for jiff
      preCheck = (oldAttrs.preCheck or "") + ''
        export TZDIR=${final.tzdata}/share/zoneinfo
      '';
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
      version = "1.6.1";

      src = final.fetchFromGitHub {
        owner = "earendil-works";
        repo = "pi";
        tag = "v${finalAttrs.version}";
        hash = "sha256-0sJNgCA6p1ZwsxI3tumtPu2LEqECt1Hqv1jQ+ASe2EY=";
      };

      npmDepsHash = "sha256-WLez4/tAmJIQysd/0J6qHm64vo6zCgaaubrtcoVXBsk=";

      npmDeps = final.fetchNpmDeps {
        inherit (finalAttrs) src;
        name = "${finalAttrs.pname}-${finalAttrs.version}-npm-deps";
        hash = finalAttrs.npmDepsHash;
      };

      modelData = final.fetchurl {
        url = "https://registry.npmjs.org/@earendil-works/pi-ai/-/pi-ai-${finalAttrs.version}.tgz";
        hash = "sha256-GSxAe9acBjWMaFGapikK3INisTK+6RF0gMdgRFbVBzs=";
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
                  @earendil-works/pi-schema:packages/schema \
                  @earendil-works/pi-telemetry:packages/telemetry \
                  @earendil-works/pi-tui:packages/tui; do
          IFS=: read -r pkg src <<< "$ws"
          rm "$nm/$pkg"
          cp -r "$src" "$nm/$pkg"
        done

        # 1.5.x added apps/* workspaces (e.g. the private apps/p2) that aren't installed
        find "$nm" -type l \( -lname '*/packages/*' -o -lname '*/apps/*' \) -delete
        find "$nm/.bin" -xtype l -delete
      '';
    }
  );
}
