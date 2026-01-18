# To build a specific package:
# nix-build -E 'with import <nixpkgs> {}; callPackage ./overlays/<file> {}'
# or
# nix build --impure --expr 'let pkgs = import <nixpkgs> {}; in pkgs.callPackage /home/dzervas/Lab/dotfiles/overlays/<file> {}'
# To find the nix store path of a package:
# nix path-info --impure --expr 'let pkgs = import <nixpkgs> {}; in pkgs.callPackage /home/dzervas/Lab/dotfiles/overlays/<file> {}'
# To remove the build output of a nix store path:
# nix-store --delete /nix/store/hash
final: prev: rec {
  buspirate5-firmware = prev.callPackage ./buspirate5-firmware.nix {};
  claude-chrome = prev.callPackage ./claude-chrome.nix {};
  mcp-gateway = prev.callPackage ./mcp-gateway.nix {};
  lmstudio-python = prev.callPackage ./lmstudio-python.nix {};
  openspec = prev.callPackage ./openspec.nix {};
  voxtype = prev.callPackage ./voxtype.nix {};
  # codex = prev.callPackage ./codex.nix {};

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
    version = "2.1.12";
    src = final.fetchzip {
      url = "https://registry.npmjs.org/@anthropic-ai/claude-code/-/claude-code-${version}.tgz";
      hash = "sha256-JX72YEM2fXY7qKVkuk+UFeef0OhBffljpFBjIECHMXw=";
    };
    npmDepsHash = "sha256-DNdRkN/rpCsN8fnZbz18r2KRUTl5HCur+GyrofH+T/Y=";
  };

  # nix-update:snacks-nvim-stable
  snacks-nvim-stable = prev.vimPlugins.snacks-nvim.overrideAttrs rec {
    version = "2.30.0";
    src = final.fetchFromGitHub {
      owner = "folke";
      repo = "snacks.nvim";
      rev = "v${version}";
      hash = "sha256-5m65Gvc6DTE9v7noOfm0+iQjDrqnrXYYV9QPnmr1JGY=";
    };
    doCheck = false; # Fails in explorer.init
  };

  # tree-sitter-cli = prev.tree-sitter.overrideAttrs (_new: _old: let
  #     grammars = prev.tree-sitter.withPlugins (_: prev.tree-sitter.allGrammars);
  #   in {
  #     postPatch = "ln -s ${grammars} parser";
  #   }
  # ).override { webUISupport = true; } ;

  # nix -update:codex-latest: --version-regex "rust-v(.*)"
  # codex-latest = prev.codex.overrideAttrs (new: old: rec {
  #   version = "0.72.0";
  #   src = prev.fetchFromGitHub {
  #     owner = "openai";
  #     repo = "codex";
  #     tag = "rust-v${new.version}";
  #     hash = "sha256-rNol7k/CcAKJXZYsbORRqD+uJfN6TPfcEbkUXezpFkY=";
  #   };
  #
  #   # cargoDeps = old.cargoDeps.overrideAttrs (prev.lib.const {
  #   #   name = "codex-latest-vendor";
  #   #   inherit src;
  #   #   outputHash = "sha256-rNol7k/CcAKJXZYsbORRqD+uJfN6TPfcEbkUXezpFkY=";
  #   # });
  #   cargoHash = "";
  #   # cargoLock.lockFile = src.out + "/Cargo.lock";
  # });
}
