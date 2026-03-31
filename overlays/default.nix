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
  # nix-update:n8n-cli
  n8n-cli = prev.callPackage ./n8n-cli.nix { };

  python = prev.python3.override {
    self = python;
    packageOverrides = pyfinal: pyprev: {
      # lmstudio-python = pyprev.callPackage ./lmstudio-python.nix {};
      openai-agents = pyprev.openai-agents.overridePythonAttrs {
        dependencies = [ pyfinal.litellm ] ++ pyprev.openai-agents.dependencies;
      };
    };
  };

  # nix-update:claude-code-latest
  claude-code-latest = prev.claude-code.overrideAttrs rec {
    version = "2.1.87";
    src = final.fetchzip {
      url = "https://registry.npmjs.org/@anthropic-ai/claude-code/-/claude-code-${version}.tgz";
      hash = "sha256-jorpY6ao1YgkoTgIk1Ae2BQCbqOuEtwzoIG36BP5nG4=";
    };
    npmDepsHash = "sha256-DNdRkN/rpCsN8fnZbz18r2KRUTl5HCur+GyrofH+T/Y=";
  };
}
