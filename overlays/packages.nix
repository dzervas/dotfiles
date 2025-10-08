_final: prev: {
  buspirate5-firmware = prev.callPackage ./buspirate5-firmware.nix {};
  mcp-gateway = prev.callPackage ./mcp-gateway.nix {};
  # nix-update:claude-code
  claude-code = prev.claude-code.overrideAttrs (_new: _old: rec {
    version = "2.0.10";
    src = prev.fetchzip {
      url = "https://registry.npmjs.org/@anthropic-ai/claude-code/-/claude-code-${version}.tgz";
      hash = "sha256-f90cIyUofV3emYtluLL/KtfAsgjG3gFQGQPGYgDWL2M=";
    };
    npmDepsHash = null;
  });
}
