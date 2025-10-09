_final: prev: {
  buspirate5-firmware = prev.callPackage ./buspirate5-firmware.nix {};
  mcp-gateway = prev.callPackage ./mcp-gateway.nix {};
  # nix-update:claude-code
  claude-code = prev.claude-code.overrideAttrs (_new: _old: rec {
    version = "2.0.11";
    src = prev.fetchzip {
      url = "https://registry.npmjs.org/@anthropic-ai/claude-code/-/claude-code-${version}.tgz";
      hash = "sha256-h+xNtaA2X9uFlmQgaRUEXB0utIpC9FT2tn+QnnWMVSs=";
    };
    npmDepsHash = null;
  });
}
