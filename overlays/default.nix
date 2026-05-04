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
    src = final.fetchurl (let
      nodePlatform = final.stdenvNoCC.hostPlatform.node;
    in {
      url = "https://storage.googleapis.com/claude-code-dist-86c565f3-f756-42ad-8dfa-d59b1c096819/claude-code-releases/${version}/${nodePlatform.platform}-${nodePlatform.arch}/claude";
      hash = "sha256-4iMkUUln/y1en5Hw7jfkZ1v4tt/sJ/r7GcslzFsj/K8=";
    });
  };

  # nix-update:pi-coding-agent-latest
  pi-coding-agent-latest = prev.pi-coding-agent.overrideAttrs (finalAttrs: _prevAttrs: rec {
    version = "0.72.1";

    src = final.fetchFromGitHub {
      owner = "badlogic";
      repo = "pi-mono";
      tag = "v${version}";
      hash = "sha256-SqUxghc60P3HfmaFJGB/m23mvzw0cD7cDEUrNFOqo0Y=";
    };

    npmDepsHash = "sha256-KUC1xQK6oJXtg962YeLOnO76uTdR10/VNa9iiCdT3VM=";

    npmDeps = final.fetchNpmDeps {
      inherit (finalAttrs) src;
      name = "${finalAttrs.pname}-${finalAttrs.version}-npm-deps";
      hash = finalAttrs.npmDepsHash;
    };
  });
}
