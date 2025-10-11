final: prev: {
  buspirate5-firmware = prev.callPackage ./buspirate5-firmware.nix {};
  mcp-gateway = prev.callPackage ./mcp-gateway.nix {};

  # nix-update:claude-code
  claude-code = prev.claude-code.overrideAttrs (_new: _old: rec {
    version = "2.0.14";
    src = final.fetchzip {
      url = "https://registry.npmjs.org/@anthropic-ai/claude-code/-/claude-code-${version}.tgz";
      hash = "sha256-U/wd00eva/qbSS4LpW1L7nmPW4dT9naffeMkHQ5xr5o=";
    };
  });

  # nix- update:codex: --version-regex "rust-v(.*)"
  # codex = prev.codex.overrideAttrs (new: old: rec {
  #   version = "rust-v0.46.0";
  #   src = prev.fetchFromGitHub {
  #     owner = "openai";
  #     repo = "codex";
  #     tag = "rust-v${new.version}";
  #     hash = "sha256-o898VjjPKevr1VRlRhJUNWsrHEGEn7jkdzWBj+DpbCs=";
  #   };
  #
  #   cargoDeps = old.cargoDeps.overrideAttrs (prev.lib.const {
  #     name = "codex-vendor";
  #     inherit src;
  #     # outputHash = "sha256-o898VjjPKevr1VRlRhJUNWsrHEGEn7jkdzWBj+DpbCs=";
  #   });
  #   cargoHash = "sha256-o898VjjPKevr1VRlRhJUNWsrHEGEn7jkdzWBj+DpbCs=";
  # });
}
