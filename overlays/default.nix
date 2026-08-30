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
  # nix-update:codex-latest
  codex-latest = prev.callPackage ./codex.nix { };
  # nix-update:anytype-cli
  anytype-cli = prev.callPackage ./anytype-cli.nix { };
  # nix-update :n8n-cli --version-regex 'n8n@(2\.\d+\.\d+)'
  n8n-cli = prev.callPackage ./n8n-cli.nix { };

  # nix-update:pi-coding-agent-latest --custom-dep modelData
  # Broken:
  pi-coding-agent-latest = prev.pi-coding-agent.overrideAttrs (
    finalAttrs: _prevAttrs: rec {
      version = "0.84.2";

      src = final.fetchFromGitHub {
        owner = "earendil-works";
        repo = "pi";
        tag = "v${version}";
        hash = "sha256-d29ft9otYxdHRWYIAX8KMHPpppToX9ME5LbPb1rPcYo=";
      };

      npmDepsHash = "sha256-6J5Efe+6ptCuR3VZojwYPZO8BBnnZsOQ4OAeB64uYOY=";

      npmDeps = final.fetchNpmDeps {
        inherit (finalAttrs) src;
        name = "${finalAttrs.pname}-${finalAttrs.version}-npm-deps";
        hash = finalAttrs.npmDepsHash;
      };

      modelData = final.fetchurl {
        url = "https://registry.npmjs.org/@earendil-works/pi-ai/-/pi-ai-${version}.tgz";
        hash = "sha256-AmJ4Wnaw6y7sWWzYp6su4j7vidLvG7EhHE8KGUTaz0E=";
      };
    }
  );
}
