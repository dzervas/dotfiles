# To build a specific package:
# nix-build -E 'with import <nixpkgs> {}; callPackage ./overlays/<file> {}'
# or
# nix build --impure --expr 'let pkgs = import <nixpkgs> {}; in pkgs.callPackage /home/dzervas/Lab/dotfiles/overlays/<file> {}'
# To find the nix store path of a package:
# nix path-info --impure --expr 'let pkgs = import <nixpkgs> {}; in pkgs.callPackage /home/dzervas/Lab/dotfiles/overlays/<file> {}'
# To remove the build output of a nix store path:
# nix-store --delete /nix/store/hash
final: prev: rec {
  buspirate5-firmware = prev.callPackage ./buspirate5-firmware.nix { };
  claude-chrome = prev.callPackage ./claude-chrome.nix { };
  lmstudio-python = prev.callPackage ./lmstudio-python.nix { };
  # nix-update:voxtype
  voxtype = prev.callPackage ./voxtype.nix { };
  # nix-update:webctl
  webctl = prev.callPackage ./webctl.nix { };
  # nix-update:codex-latest
  codex-latest = prev.callPackage ./codex.nix { };
  # nix-update:anytype-cli
  anytype-cli = prev.callPackage ./anytype-cli.nix { };
  # nix-update :n8n-cli --version-regex 'n8n@(2\.\d+\.\d+)'
  n8n-cli = prev.callPackage ./n8n-cli.nix { };
  # nix-update :playwright-cli --version-regex 'n8n@(2\.\d+\.\d+)'
  playwright-cli = prev.callPackage ./playwright-cli.nix { };

  python = prev.python3.override {
    self = python;
    packageOverrides = pyfinal: pyprev: {
      # lmstudio-python = pyprev.callPackage ./lmstudio-python.nix {};
      openai-agents = pyprev.openai-agents.overridePythonAttrs {
        dependencies = [ pyfinal.litellm ] ++ pyprev.openai-agents.dependencies;
      };
    };
  };

  # nix-update :claude-code-latest
  claude-code-latest = prev.claude-code.overrideAttrs rec {
    # Get from https://storage.googleapis.com/claude-code-dist-86c565f3-f756-42ad-8dfa-d59b1c096819/claude-code-releases/latest
    version = "2.1.92";
    src = final.fetchurl (
      let
        nodePlatform = final.stdenvNoCC.hostPlatform.node;
      in
      {
        url = "https://storage.googleapis.com/claude-code-dist-86c565f3-f756-42ad-8dfa-d59b1c096819/claude-code-releases/${version}/${nodePlatform.platform}-${nodePlatform.arch}/claude";
        hash = "sha256-4iMkUUln/y1en5Hw7jfkZ1v4tt/sJ/r7GcslzFsj/K8=";
      }
    );
  };

  # nix-update:pi-coding-agent-latest
  pi-coding-agent-latest = prev.pi-coding-agent.overrideAttrs (
    finalAttrs: _prevAttrs: rec {
      version = "0.78.0";

      src = final.fetchFromGitHub {
        owner = "badlogic";
        repo = "pi-mono";
        tag = "v${version}";
        # Upstream's 0.74.0 lockfile omits resolved/integrity metadata for many
        # packages, so fetchNpmDeps cannot populate npm's offline cache from it.
        # This is the nixpkgs-standard lockfile normalizer for that npm bug.
        postFetch = ''
          ${final.lib.getExe final.npm-lockfile-fix} $out/package-lock.json
        '';
        hash = "sha256-DyBKC9q2XMsEUS2nGKZKeqd1hn7Tth/2O96oKxoAp48=";
      };

      npmDepsHash = "sha256-2QXQPjn0PRa17NzE0db1bvMd4d23eKqsZWQfI3muCpU=";

      npmDeps = final.fetchNpmDeps {
        inherit (finalAttrs) src;
        name = "${finalAttrs.pname}-${finalAttrs.version}-npm-deps";
        hash = finalAttrs.npmDepsHash;
      };

      # nixpkgs 0.70.5 still copies the old @mariozechner workspace packages.
      # 0.74.0 renamed them to @earendil-works, but the runtime still needs real
      # package directories instead of workspace symlinks into packages/.
      postInstall = ''
        local nm="$out/lib/node_modules/pi-monorepo/node_modules"

        # Replace workspace deps needed at runtime with real copies.
        for ws in @earendil-works/pi-ai:packages/ai \
                  @earendil-works/pi-agent-core:packages/agent \
                  @earendil-works/pi-tui:packages/tui; do
          IFS=: read -r pkg src <<< "$ws"
          rm "$nm/$pkg"
          cp -r "$src" "$nm/$pkg"
        done

        # Delete remaining workspace symlinks.
        find "$nm" -type l -lname '*/packages/*' -delete

        # Clean up now-dangling .bin symlinks.
        find "$nm/.bin" -xtype l -delete
      '';
    }
  );
}
