_final: prev: {
  buspirate5-firmware = prev.callPackage ./buspirate5-firmware.nix {};
  mcp-gateway = prev.callPackage ./mcp-gateway.nix {};
  claude-code = prev.claude-code.overrideAttrs (_new: _old: rec {
    version = "2.0.9";
    src = prev.fetchzip {
      url = "https://registry.npmjs.org/@anthropic-ai/claude-code/-/claude-code-${version}.tgz";
      hash = "sha256-eBhg8RCATVIgC5Dex+cTnLDzLKfnJI8M7eOSGDE4bAw=";
    };
    npmDepsHash = null;
  });
}
